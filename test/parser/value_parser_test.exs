defmodule Rez.Parser.ValueParserTest do
  use ExUnit.Case

  alias Ergo.Context
  alias Rez.Parser.ValueParsers

  test "parses die values" do
    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.dice_value(), "1d6+1")
  end

  test "parses hereoc strings" do
    input = ~s|"""Heredoc string"""|

    assert %Context{status: :ok, ast: {:string, "Heredoc string"}} =
             Ergo.parse(ValueParsers.heredoc_value(), input)
  end
end
