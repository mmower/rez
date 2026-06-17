defmodule Rez.Parser.ValueParserTest do
  use ExUnit.Case

  alias Ergo.Context
  alias Rez.Parser.ValueParsers

  test "parses initializer roll values" do
    assert %Context{status: :ok, ast: {:initializer_roll, {3, 6, 0, 1, 10}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^ir:3d6")

    assert %Context{status: :ok, ast: {:initializer_roll, {1, 4, 0, 1, 10}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^ir:d4")

    assert %Context{status: :ok, ast: {:initializer_roll, {2, 6, 3, 1, 10}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^ir:2d6+3")

    assert %Context{status: :ok, ast: {:initializer_roll, {1, 10, 0, 1, 5}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^ir:5:1d10")

    assert %Context{status: :ok, ast: {:initializer_roll, {3, 6, 0, 1, 10}}} =
             Ergo.parse(ValueParsers.value(), "^ir:3d6")
  end

  test "parses die values" do
    input = "^r:1d6+1"

    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.dice_value(), input)

    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses die values with explicit rounds" do
    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 2}}} =
             Ergo.parse(ValueParsers.dice_value(), "^r:1d6+1:2")
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

  test "parses elem name (tag ref) values" do
    input = "@card"

    assert %Context{status: :ok, ast: {:elem_name, "card"}} =
             Ergo.parse(ValueParsers.elem_name_value(), input)

    assert %Context{status: :ok, ast: {:elem_name, "card"}} =
             Ergo.parse(ValueParsers.value(), input)
  end

  test "parses elem name with underscores" do
    input = "@my_location"

    assert %Context{status: :ok, ast: {:elem_name, "my_location"}} =
             Ergo.parse(ValueParsers.elem_name_value(), input)
  end

  test "parses ^init long-form dynamic initializer" do
    assert %Context{status: :ok, ast: {:dynamic_initializer, {"return 1;", 10}}} =
             Ergo.parse(ValueParsers.dynamic_initializer_value(), "^init{return 1;}")

    assert %Context{status: :ok, ast: {:dynamic_initializer, {"return 1;", 5}}} =
             Ergo.parse(ValueParsers.dynamic_initializer_value(), "^init:5{return 1;}")

    assert %Context{status: :ok, ast: {:dynamic_initializer, {"return 1;", 10}}} =
             Ergo.parse(ValueParsers.value(), "^init{return 1;}")
  end

  test "parses ^prop long-form property" do
    assert %Context{status: :ok, ast: {:property, "return this.bar;"}} =
             Ergo.parse(ValueParsers.property_value(), "^prop{return this.bar;}")

    assert %Context{status: :ok, ast: {:property, "return this.bar;"}} =
             Ergo.parse(ValueParsers.value(), "^prop{return this.bar;}")
  end

  test "parses ^copy long-form copy initializer" do
    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 10}}} =
             Ergo.parse(ValueParsers.copy_initializer_value(), "^copy:#some_element")

    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 5}}} =
             Ergo.parse(ValueParsers.copy_initializer_value(), "^copy:5:#some_element")

    assert %Context{status: :ok, ast: {:copy_initializer, {"some_element", 10}}} =
             Ergo.parse(ValueParsers.value(), "^copy:#some_element")
  end

  test "parses ^roll long-form dice value" do
    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.dice_value(), "^roll:1d6+1")

    assert %Context{status: :ok, ast: {:roll, {1, 6, 1, 1}}} =
             Ergo.parse(ValueParsers.value(), "^roll:1d6+1")
  end

  test "parses initializer roll with explicit rounds" do
    assert %Context{status: :ok, ast: {:initializer_roll, {3, 6, 0, 2, 10}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^ir:3d6:2")
  end

  test "parses ^init_roll long-form initializer roll" do
    assert %Context{status: :ok, ast: {:initializer_roll, {3, 6, 0, 1, 10}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^init_roll:3d6")

    assert %Context{status: :ok, ast: {:initializer_roll, {1, 10, 0, 1, 5}}} =
             Ergo.parse(ValueParsers.initializer_roll_value(), "^init_roll:5:1d10")

    assert %Context{status: :ok, ast: {:initializer_roll, {3, 6, 0, 1, 10}}} =
             Ergo.parse(ValueParsers.value(), "^init_roll:3d6")
  end
end
