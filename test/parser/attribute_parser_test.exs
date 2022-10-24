defmodule Rez.Parser.AttributeParserTest do
  use ExUnit.Case
  doctest Rez.Parser.AttributeParser

  alias Ergo.Context
  import Rez.Parser.AttributeParser

  test "parses heredoc value" do
    input = """
    \"\"\"Now is the winter of our discontent made glorious summer by this son of York.\"\"\"
    """
    assert %Context{status: :ok, ast: {:string, "Now is the winter of our discontent made glorious summer by this son of York."}} = Ergo.parse(heredoc_value(), input)
  end

  test "parses string value" do
    input = "\"Now is the winter of our discontent made glorious summer by this son of York.\""
    assert %Context{status: :ok, ast: {:string, "Now is the winter of our discontent made glorious summer by this son of York."}} = Ergo.parse(string_value(), input)
  end

  test "parses interpolated string value" do
    input = "\"Now is the ${season} of our ${feeling}\""
    assert %Context{status: :ok, ast: {:dstring, "Now is the ${season} of our ${feeling}"}} = Ergo.parse(string_value(), input)
  end

  test "parses heredoc attribute" do
    input = """
    quote: \"\"\"Now is the winter of our discontent made glorious summer by this son of York.\"\"\"
    """
    assert %Context{status: :ok, ast: %Rez.AST.Attribute{name: "quote", type: :string, value: "Now is the winter of our discontent made glorious summer by this son of York."}} = Ergo.parse(attribute(), input)
  end

  test "parses lists" do
    ctx = Ergo.parse(list_value(), "[]")
    assert :ok = ctx.status
    assert {:list, []} = ctx.ast

    ctx = Ergo.parse(list_value(), "[1 2 3]")
    assert :ok = ctx.status
    assert {:list, [{:number, 1}, {:number, 2}, {:number, 3}]} = ctx.ast
  end

  test "parses empty table value" do
    input = """
    {}
    """

    assert %Context{status: :ok, ast: {:table, %{}}} = Ergo.parse(table_value(), input)
  end

  test "parses one level table value" do
    input = """
    {
      alpha: true
      beta: 1
      delta: "delta"
      epsilon: #foo
      gamma: 2.0
    }
    """

    assert %Context{status: :ok, ast: {:table, %{"alpha" => %Rez.AST.Attribute{name: "alpha", type: :boolean, value: true}, "beta" => %Rez.AST.Attribute{name: "beta", type: :number, value: 1}, "delta" => %Rez.AST.Attribute{name: "delta", type: :string, value: "delta"}, "epsilon" => %Rez.AST.Attribute{name: "epsilon", type: :elem_ref, value: "foo"}, "gamma" => %Rez.AST.Attribute{name: "gamma", type: :number, value: 2.0}}}} = Ergo.parse(table_value(), input)
  end

  test "parses nested table value" do
    input = """
    {
      alpha: {
        beta: true
      }
    }
    """

    assert %Context{status: :ok, ast: {:table, %{"alpha" => %Rez.AST.Attribute{name: "alpha", type: :table, value: %{"beta" => %Rez.AST.Attribute{name: "beta", type: :boolean, value: true}}}}}} = Ergo.parse(table_value(), input)
  end

  test "parse double iows" do
    import Ergo.{Combinators, Terminals}
    import Rez.Parser.UtilityParsers, only: [iows: 0]

    parser = sequence([literal("a"), iows(), iows(), literal("b")])
    assert %Context{status: :ok, ast: ["a", "b"]} = Ergo.parse(parser, "ab")
  end

end
