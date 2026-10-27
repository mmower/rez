defmodule Rez.Parser.JSBlockParserTest do
  use ExUnit.Case

  alias Ergo.Context
  import Rez.Parser.JSBlockParser

  defp block(input), do: Ergo.parse(js_block(?{, ?}), input)

  # Asserts the whole block parses, with `rest` left over afterwards
  defp assert_block(body, rest \\ "") do
    assert %Context{status: :ok, ast: ^body, input: ^rest} = block(body <> rest)
  end

  describe "nesting" do
    test "empty block" do
      assert_block("{}")
    end

    test "nested braces" do
      assert_block("{ if (x) { y = {a: {b: 1}}; } }", " tail")
    end

    test "array mode only counts brackets" do
      assert %Context{status: :ok, ast: "[1, [2, {a: 3}], \"]\"]", input: " x"} =
               Ergo.parse(js_block(?[, ?]), "[1, [2, {a: 3}], \"]\"] x")
    end
  end

  describe "strings" do
    test "braces inside double and single quoted strings" do
      assert_block(~s|{ a = "}"; b = '{'; }|, "rest")
    end

    test "escaped quotes" do
      assert_block(~S|{ a = "\"}"; b = '\'}'; }|)
    end

    test "unterminated string ends at the line break" do
      assert_block("{ a = \"oops\n}", "rest")
    end
  end

  describe "template literals" do
    test "braces inside a template" do
      assert_block("{ s = `}${x}{`; }")
    end

    test "object literal inside an interpolation" do
      assert_block("{ s = `${ {a: '}'}.a }`; }")
    end

    test "nested templates" do
      assert_block("{ s = `a ${ `b ${ c } }` } d`; }")
    end

    test "multi-line template" do
      assert_block("{ s = `line 1 }\nline 2 {`; }")
    end
  end

  describe "comments" do
    test "line comment" do
      assert_block("{ x = 1; // closes } here?\n y = 2; }")
    end

    test "block comment" do
      assert_block("{ /* } \n { */ x = 1; }")
    end

    test "quotes inside comments are ignored" do
      assert_block("{ // don't\n x = 1; /* it's */ }")
    end
  end

  describe "regex literals" do
    test "brace in a regex" do
      assert_block("{ return /}/.test(s); }")
    end

    test "quote in a regex" do
      assert_block(~S|{ s = s.replace(/"/g, '&quot;'); }|)
    end

    test "escaped slashes do not start a comment" do
      assert_block(~S|{ s = s.replace(/\/\//g, ""); }|)
    end

    test "slash inside a character class" do
      assert_block("{ r = /[/}]/; }")
    end

    test "division after an identifier is not a regex" do
      assert_block(~s|{ x = a / 2; s = "/"; }|)
    end

    test "division after a closing paren is not a regex" do
      assert_block(~s|{ x = (a + b) / 2 + "}" / 3; }|)
    end

    test "unclosed slash on a line is treated as division" do
      assert_block("{ x = (1, / 2);\n y = '}'; }")
    end
  end

  describe "errors" do
    test "unterminated block" do
      assert %Context{status: {:error, [{:unterminated_block, {1, 1}, _} | _]}} =
               block("{ if (x) { }")
    end

    test "unterminated block comment" do
      assert %Context{status: {:error, [{:unterminated_block, _, _} | _]}} = block("{ /* } ")
    end

    test "wrong opening character" do
      assert %Context{status: {:error, [{:unexpected_char, _, _} | _]}} = block("x{}")
    end

    test "empty input" do
      assert %Context{status: {:error, [{:unexpected_eoi, _, _} | _]}} = block("")
    end
  end

  describe "position tracking" do
    test "matches Ergo's delimited_text for plain input" do
      input = "{\n  héllo = {\"wörld\": 1};\n  return x;\n}after"

      expected = Ergo.parse(Ergo.Terminals.delimited_text(?{, ?}), input)
      actual = block(input)

      assert actual.ast == expected.ast
      assert actual.input == expected.input

      assert {actual.line, actual.col, actual.index} ==
               {expected.line, expected.col, expected.index}
    end

    test "single line block advances column only" do
      assert %Context{line: 1, col: 7, index: 6} = block("{ a; }x")
    end

    test "consumed reflects the block" do
      ctx = block("{ a }rest")
      assert Context.consumed(ctx) == "{ a }"
    end
  end
end
