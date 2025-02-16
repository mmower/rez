defmodule Rez.Parser.ValueParserTest do
  use ExUnit.Case

  alias Ergo.Context
  alias Rez.Parser.ValueParsers

  test "parses die values" do
    input = "^r:1d6+1"

    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.dice_value(), input)

    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses die values with no prefix" do
    input = "^r:d4"

    assert %Context{status: :ok, ast: {:roll, {1, 4, 0, 1}}} =
             Ergo.parse(ValueParsers.dice_value(), input)
  end

  test "parses hereoc strings" do
    input = ~s|"""Heredoc string"""|

    assert %Context{status: :ok, ast: {:string, "Heredoc string"}} =
             Ergo.parse(ValueParsers.heredoc_value(), input)
  end
end
