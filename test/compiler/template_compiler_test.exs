defmodule Rez.Compiler.TemplateCompilerTest do
  use ExUnit.Case

  alias Rez.Compiler.TemplateCompiler, as: C
  alias Rez.Parser.TemplateParser, as: P
  alias Rez.Parser.TemplateExpressionParser, as: TEP

  # @tag :skip
  test "compiles string chunk to string function" do
    assert "function(bindings, filters) {return `The rain in Spain falls mainly on the plain.`;}" =
             C.compile_chunk("The rain in Spain falls mainly on the plain.")
  end

  # @tag :skip
  test "compile interpolate chunk to interpolate function" do
    {:ok, chunk} = TEP.parse("player.name")

    assert ~s|function(bindings, filters) {return [].reduce(function(value, filter) {return filter(bindings, value);}, (function(bindings) {return bindings.player.name;})(bindings));}| =
             C.compile_chunk({:interpolate, chunk})
  end

  # @tag :skip
  def strip_extraneous_whitespace(s) when is_binary(s) do
    r1 = Regex.replace(~r/\t\n/, s, "")
    Regex.replace(~r/\s+/, r1, " ")
  end

  # @tag :skip
  test "compile conditional chunk into render function" do
    chunk = {:conditional, "player.health < 50", "<div>wounded!</div>"}

    assert "function(bindings, filters) {return (player.health < 50) ? `<div>wounded!</div>` : ``;}" =
             C.compile_chunk(chunk)
  end

  # @tag :skip
  test "compile chunks into template functions" do
    template = """
    This is text containing an interpolation ${player.name} of the players name.
    """

    assert {:compiled_template,
            ~s|function(bindings, filters) {return [function(bindings, filters) {return `This is text containing an interpolation `;},function(bindings, filters) {return [].reduce(function(value, filter) {return filter(bindings, value);}, (function(bindings) {return bindings.player.name;})(bindings));},function(bindings, filters) {return ` of the players name.\n`;}].reduce(function(text, f) {return text + f(bindings, filters)}, "");}|} =
             template |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compiler" do
    assert {:compiled_template,
            ~s|function(bindings, filters) {return [function(bindings, filters) {return [].reduce(function(value, filter) {return filter(bindings, value);}, (function(bindings) {return bindings.person.age;})(bindings));}].reduce(function(text, f) {return text + f(bindings, filters)}, "");}|} =
             "${person.age}" |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compile interpolate chunk using a value" do
    template = P.parse("${\"year\" | pluralize: player.age}")

    assert {:compiled_template,
            ~s|function(bindings, filters) {return [function(bindings, filters) {return [function(bindings, value) {return filters.pluralize(value, (function(bindings) {return bindings.player.age;})(bindings));}].reduce(function(value, filter) {return filter(bindings, value);}, (function(bindings) {return "year";})(bindings));}].reduce(function(text, f) {return text + f(bindings, filters)}, "");}|} =
             C.compile(template)
  end
end
