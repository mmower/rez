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

  test "parses constant references" do
    input = "$MAX_HEALTH"

    assert %Context{status: :ok, ast: {:const_ref, "MAX_HEALTH"}} =
             Ergo.parse(ValueParsers.const_ref_value(), input)

    assert %Context{status: :ok, ast: {:const_ref, "MAX_HEALTH"}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses constant references with underscores" do
    input = "$my_const"

    assert %Context{status: :ok, ast: {:const_ref, "my_const"}} =
             Ergo.parse(ValueParsers.const_ref_value(), input)
  end

  # test "parses hereoc strings" do
  #   input = ~s|"""Heredoc string"""|

  #   assert %Context{status: :ok, ast: {:string, "Heredoc string"}} =
  #            Ergo.parse(ValueParsers.heredoc_value(), input)
  # end

  test "parses copy initializer values" do
    input = "^c:#some_element"

    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 10}}} =
             Ergo.parse(ValueParsers.copy_initializer_value(), input)

    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 10}}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses copy initializer values with priority" do
    input = "^c:5:#some_element"

    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 5}}} =
             Ergo.parse(ValueParsers.copy_initializer_value(), input)
  end

  test "copy initializer without # produces helpful error" do
    input = "^c:some_element"

    result = Ergo.parse(ValueParsers.copy_initializer_value(), input)
    assert {:fatal, _} = result.status
    # Error indicates it expected # but got s
    [{:unexpected_char, _, msg}] = elem(result.status, 1)
    assert msg =~ "#"
  end

  test "parses delegate values" do
    input = "^d:hull"

    assert %Context{status: :ok, ast: {:delegate, "hull"}} =
             Ergo.parse(ValueParsers.delegate_value(), input)

    assert %Context{status: :ok, ast: {:delegate, "hull"}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses delegate values with underscores" do
    input = "^d:parent_ship"

    assert %Context{status: :ok, ast: {:delegate, "parent_ship"}} =
             Ergo.parse(ValueParsers.delegate_value(), input)
  end

  test "delegate without attribute name fails" do
    input = "^d:"

    result = Ergo.parse(ValueParsers.delegate_value(), input)
    assert {:fatal, _} = result.status
  end
end
