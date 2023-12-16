defmodule Rez.Compiler.TemplateCompilerTest do
  use ExUnit.Case

  alias Rez.Compiler.TemplateCompiler, as: C
  alias Rez.Parser.TemplateParser, as: P
  alias Rez.Parser.TemplateExpressionParser, as: TEP

  # @tag :skip
  test "compiles string chunk to string function" do
    assert "function(bindings) {return `The rain in Spain falls mainly on the plain.`;}" =
             C.compile_chunk("The rain in Spain falls mainly on the plain.")
  end

  # @tag :skip
  test "compile interpolate chunk to interpolate function" do
    {:ok, chunk} = TEP.parse("player.name")

    assert ~s|function(bindings) {return (function(bindings) {return bindings.player.name;})(bindings);}| =
             C.compile_chunk({:interpolate, chunk})
  end

  # @tag :skip
  def strip_extraneous_whitespace(s) when is_binary(s) do
    r1 = Regex.replace(~r/\t\n/, s, "")
    Regex.replace(~r/\s+/, r1, " ")
  end

  # @tag :skip
  test "compile conditional chunk into render function" do
    chunk = {:conditional, "player.health < 50", {:source_template, ["<div>wounded!</div>"]}}

    assert "function(bindings) { \n    if(evaluateExpression(`player.health < 50`, bindings)) {\n      const sub_template = function(bindings) {return [function(bindings) {return `<div>wounded!</div>`;}].reduce(function(text, f) {return text + f(bindings)}, \"\");};\n      return sub_template(bindings);\n    } else {\n      return \"\";\n    };}" =
             C.compile_chunk(chunk)
  end

  # @tag :skip
  test "compile chunks into template functions" do
    template = """
    This is text containing an interpolation ${player.name} of the players name.
    """

    assert {:compiled_template,
            ~s|function(bindings) {return [function(bindings) {return `This is text containing an interpolation `;},function(bindings) {return (function(bindings) {return bindings.player.name;})(bindings);},function(bindings) {return ` of the players name.\n`;}].reduce(function(text, f) {return text + f(bindings)}, \"\");}|} =
             template |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compiler" do
    assert {:compiled_template,
            ~s|function(bindings) {return [function(bindings) {return (function(bindings) {return bindings.person.age;})(bindings);}].reduce(function(text, f) {return text + f(bindings)}, \"\");}|} =
             "${person.age}" |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compile interpolate chunk using a value" do
    template = P.parse("${\"year\" | pluralize: player.age}")

    assert {:compiled_template,
            ~s|function(bindings) {return [function(bindings) {return [function(bindings, value) {return Rez.template_expression_filters.pluralize(value, (function(bindings) {return bindings.player.age;})(bindings));}].reduce(function(value, expr_filter) {return expr_filter(bindings, value);}, (function(bindings) {return \"year\";})(bindings));}].reduce(function(text, f) {return text + f(bindings)}, \"\");}|} =
             C.compile(template)
  end

  test "filter content" do
    expr = ~s|(function(bindings) {return bindings.content;})(bindings)|

    template = P.parse("The rain in span falls mainly on the ${content} plain")
    {:compiled_template, ct} = C.compile(template)

    assert String.contains?(ct, expr)
  end
end
