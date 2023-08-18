defmodule Rez.Compiler.TemplateCompilerTest do
  use ExUnit.Case

  alias Rez.Compiler.TemplateCompiler, as: C
  alias Rez.Parser.TemplateParser, as: P
  alias Rez.Parser.TemplateExpressionParser, as: TEP

  @tag :skip
  test "compiles string chunk to string function" do
    assert "(bindings, filters) => \"The rain in Spain falls mainly on the plain.\"" =
             C.compile_chunk("The rain in Spain falls mainly on the plain.")
  end

  @tag :skip
  test "compile interpolate chunk to interpolate function" do
    {:ok, chunk} = TEP.parse("player.name")

    assert "(bindings, filters) => {const binding = bindings[\"player\"];const attr_val = binding.getAttributeValue(\"name\");return [].reduce((v, f) => f(v), attr_val);}" =
             C.compile_chunk({:interpolate, chunk})
  end

  @tag :skip
  def strip_extraneous_whitespace(s) when is_binary(s) do
    r1 = Regex.replace(~r/\t\n/, s, "")
    Regex.replace(~r/\s+/, r1, " ")
  end

  @tag :skip
  test "compile chunks into template functions" do
    template = """
    This is text containing an interpolation ${player.name} of the players name.
    """

    assert "function(bindings, filters) {return [(bindings, filters) => \"This is text containing an interpolation \",(bindings, filters) => {const binding = bindings[\"player\"];const attr_val = binding.getAttributeValue(\"name\");return [].reduce((v, f) => f(v), attr_val);},(bindings, filters) => \" of the players name.\n\"].reduce((text, f) => text + f(bindings, filters), \"\")}" =
             template |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compiler" do
    assert "" = "${person.age}" |> P.parse() |> C.compile()
  end

  @tag :skip
  test "compile interpolate chunk using a value" do
    template = P.parse("${\"year\" | pluralize: player.age}")
    assert "" = C.compile(template)
  end
end
