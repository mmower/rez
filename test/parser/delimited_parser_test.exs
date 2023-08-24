defmodule Rez.Parser.DelimitedParserTest do
  use ExUnit.Case

  import Ergo.Terminals, only: [literal: 1]
  import Rez.Parser.DelimitedParser, only: [text_delimited_by_nested_parsers: 2]

  defp make_parser(open, close) do
    text_delimited_by_nested_parsers(literal(open), literal(close))
  end

  test "Parses delimited text" do
    inner_text = "Here is some text"
    template = "{%#{inner_text}%}"
    parser = make_parser("{%", "%}")

    assert %{status: :ok, ast: ^inner_text} = Ergo.parse(parser, template)
  end

  test "Parses nested delimited text" do
    inner_text = "Here is some text with a {% nested template %} inside it"
    template = "{%#{inner_text}%}"
    parser = make_parser("{%", "%}")

    assert %{status: :ok, ast: ^inner_text} = Ergo.parse(parser, template)
  end

  test "Parses deeply nested text" do
    third_level = "another nest template"
    second_level = "nested template with {% #{third_level} %}"
    first_level = "Here is some text with a {% #{second_level} %} inside it"
    template = "{%#{first_level}%}"
    parser = make_parser("{%", "%}")

    assert %{status: :ok, ast: ^first_level} = Ergo.parse(parser, template)
  end
end
