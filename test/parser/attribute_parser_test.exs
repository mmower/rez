defmodule Rez.Parser.AttributeParserTest do
  use ExUnit.Case
  doctest Rez.Parser.AttributeParser

  alias Ergo.Context

  import Ergo.Combinators, only: [sequence: 1]
  import Ergo.Terminals, only: [literal: 1]

  import Rez.Parser.AttributeParser, only: [attribute: 0]

  import Rez.Parser.Collection.List, only: [list: 0]
  import Rez.Parser.Collection.Set, only: [set: 0]

  import Rez.Parser.ValueParsers,
    only: [
      string_value: 0,
      dice_value: 0,
      value: 0
    ]

  import Rez.Parser.UtilityParsers, only: [iows: 0]

  test "parses string value" do
    input = "\"Now is the winter of our discontent made glorious summer by this son of York.\""

    assert %Context{
             status: :ok,
             ast:
               {:string,
                "Now is the winter of our discontent made glorious summer by this son of York."}
           } = Ergo.parse(string_value(), input)
  end

  test "parses interpolated string value" do
    input = "\"Now is the ${season} of our ${feeling}\""

    assert %Context{status: :ok, ast: {:dstring, "Now is the ${season} of our ${feeling}"}} =
             Ergo.parse(string_value(), input)
  end

  test "parses lists" do
    ctx = Ergo.parse(list(), "[]")
    assert :ok = ctx.status
    assert {:list, []} = ctx.ast

    ctx = Ergo.parse(list(), "[1 2 3]")
    assert :ok = ctx.status
    assert {:list, [{:number, 1}, {:number, 2}, {:number, 3}]} = ctx.ast
  end

  test "parses list attribute" do
    src = """
    options: [1 :a]
    """

    assert %{status: :ok, ast: ast} = Ergo.parse(attribute(), src)
    assert %{value: [{:number, 1}, {:keyword, "a"}]} = ast
  end

  # test "parses empty table value" do
  #   input = """
  #   {}
  #   """

  #   assert %Context{status: :ok, ast: {:table, %{}}} = Ergo.parse(table(), input)
  # end

  # test "parses one level table value" do
  #   input = """
  #   {
  #     alpha: true
  #     beta: 1
  #     delta: "delta"
  #     epsilon: #foo
  #     gamma: 2.0
  #   }
  #   """

  #   assert %Context{
  #            status: :ok,
  #            ast:
  #              {:table,
  #               %{
  #                 "alpha" => %Rez.AST.Attribute{name: "alpha", type: :boolean, value: true},
  #                 "beta" => %Rez.AST.Attribute{name: "beta", type: :number, value: 1},
  #                 "delta" => %Rez.AST.Attribute{name: "delta", type: :string, value: "delta"},
  #                 "epsilon" => %Rez.AST.Attribute{name: "epsilon", type: :elem_ref, value: "foo"},
  #                 "gamma" => %Rez.AST.Attribute{name: "gamma", type: :number, value: 2.0}
  #               }}
  #          } = Ergo.parse(table(), input)
  # end

  # test "parses nested table value" do
  #   input = """
  #   {
  #     alpha: {
  #       beta: true
  #     }
  #   }
  #   """

  #   assert %Context{
  #            status: :ok,
  #            ast:
  #              {:table,
  #               %{
  #                 "alpha" => %Rez.AST.Attribute{
  #                   name: "alpha",
  #                   type: :table,
  #                   value: %{
  #                     "beta" => %Rez.AST.Attribute{name: "beta", type: :boolean, value: true}
  #                   }
  #                 }
  #               }}
  #          } = Ergo.parse(table(), input)
  # end

  test "parse double iows" do
    parser = sequence([literal("a"), iows(), iows(), literal("b")])
    assert %Context{status: :ok, ast: ["a", "b"]} = Ergo.parse(parser, "ab")
  end

  test "parse empty set" do
    input = "\#{}"
    empty_set = MapSet.new()

    assert %Context{status: :ok, ast: {:set, ^empty_set}} = Ergo.parse(set(), input)
  end

  test "parse dice" do
    input = "^r:1d6"
    assert %Context{status: :ok, ast: {:roll, {1, 6, 0, 1}}} = Ergo.parse(dice_value(), input)
  end

  test "parses elem refs" do
    input = ~s|#foo|
    assert %Context{status: :ok, ast: {:elem_ref, "foo"}} = Ergo.parse(value(), input)
  end
end
