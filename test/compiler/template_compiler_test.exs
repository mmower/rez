defmodule Rez.Compiler.TemplateCompilerTest do
  use ExUnit.Case

  alias Rez.Compiler.TemplateCompiler, as: C
  alias Rez.Parser.TemplateParser, as: P
  alias Rez.Parser.TemplateExpressionParser, as: TEP

  # @tag :skip
  test "compiles string chunk to string function" do
    assert "() => `The rain in Spain falls mainly on the plain.`" =
             C.compile_chunk("The rain in Spain falls mainly on the plain.")
  end

  # @tag :skip
  test "compile interpolate chunk to interpolate function" do
    {:ok, chunk} = TEP.parse("player.name")

    assert ~s|(bindings) => ((bindings) => bindings.player.name)(bindings)| =
             C.compile_chunk({:interpolate, chunk})
  end

  # @tag :skip
  def strip_extraneous_whitespace(s) when is_binary(s) do
    r1 = Regex.replace(~r/\t\n/, s, "")
    Regex.replace(~r/\s+/, r1, " ")
  end

  # @tag :skip
  test "compile conditional chunk into render function" do
    chunk = {:conditional, [{"player.health < 50", {:source_template, ["<div>wounded!</div>"]}}]}

    assert "(bindings) => {\n    if(evaluateExpression(`player.health < 50`, bindings)) {\n      const sub_template = (bindings) => [() => `<div>wounded!</div>`].reduce((text, f) => text + f(bindings), \"\");\n      return sub_template(bindings);\n    }\n      else {\n        return \"\";\n      }\n      }" =
             C.compile_chunk(chunk)
  end

  # @tag :skip
  test "compile chunks into template functions" do
    template = """
    This is text containing an interpolation ${player.name} of the players name.
    """

    assert {:compiled_template,
            ~s|(bindings) => [() => `This is text containing an interpolation `,(bindings) => ((bindings) => bindings.player.name)(bindings),() => ` of the players name.\n`].reduce((text, f) => text + f(bindings), "")|} =
             template |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compiler" do
    assert {:compiled_template,
            ~s|(bindings) => [(bindings) => ((bindings) => bindings.person.age)(bindings)].reduce((text, f) => text + f(bindings), "")|} =
             "${person.age}" |> P.parse() |> C.compile()
  end

  # @tag :skip
  test "compile interpolate chunk using a value" do
    template = P.parse("${\"year\" | pluralize: player.age}")

    assert {:compiled_template,
            ~s|(bindings) => [(bindings) => [(bindings, value) => {return Rez.template_expression_filters.pluralize(value, ((bindings) => bindings.player.age)(bindings));}].reduce((value, expr_filter) => expr_filter(bindings, value), "year")].reduce((text, f) => text + f(bindings), "")|} =
             C.compile(template)
  end

  test "filter content" do
    expr = ~s|((bindings) => bindings.content)(bindings)|

    template = P.parse("The rain in span falls mainly on the ${content} plain")
    {:compiled_template, ct} = C.compile(template)

    assert String.contains?(ct, expr)
  end

  # Index syntax compilation tests

  test "compiles numeric index access" do
    {:ok, chunk} = TEP.parse("items[0]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.items[0]")
  end

  test "compiles property after numeric index" do
    {:ok, chunk} = TEP.parse("items[0].name")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.items[0].name")
  end

  test "compiles numeric index after property" do
    {:ok, chunk} = TEP.parse("player.inventory[0]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.player.inventory[0]")
  end

  test "compiles chained numeric indices" do
    {:ok, chunk} = TEP.parse("matrix[0][1]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.matrix[0][1]")
  end

  test "compiles string key access" do
    {:ok, chunk} = TEP.parse("obj[\"special-key\"]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, ~s|bindings.obj["special-key"]|)
  end

  test "compiles bound variable index" do
    {:ok, chunk} = TEP.parse("items[idx]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.items[bindings.idx]")
  end

  test "compiles bound variable index with nested path" do
    {:ok, chunk} = TEP.parse("items[state.index]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.items[bindings.state.index]")
  end

  test "compiles multiple bound variable indices" do
    {:ok, chunk} = TEP.parse("matrix[row][col]")
    compiled = C.compile_chunk({:interpolate, chunk})

    assert String.contains?(compiled, "bindings.matrix[bindings.row][bindings.col]")
  end

  test "bound_path_to_js helper function" do
    # Test the helper function directly
    assert "bindings.arr[0]" = C.bound_path_to_js(["arr", {:index, 0}])
    assert "bindings.arr[0].name" = C.bound_path_to_js(["arr", {:index, 0}, "name"])
    assert ~s|bindings.obj["key"]| = C.bound_path_to_js(["obj", {:key, "key"}])
    assert "bindings.arr[bindings.idx]" = C.bound_path_to_js(["arr", {:bound_index, ["idx"]}])

    assert "bindings.matrix[bindings.row][bindings.col]" =
             C.bound_path_to_js(["matrix", {:bound_index, ["row"]}, {:bound_index, ["col"]}])
  end

  # @component / user_component compilation tests

  test "compile self-closing component references user_components" do
    compiled = C.compile_chunk({:user_component, "foo", %{}, nil})

    assert String.contains?(compiled, "window.Rez.user_components.foo")
    assert String.contains?(compiled, ~s|No user @component foo defined!|)
  end

  test "compile self-closing component with string attribute" do
    compiled = C.compile_chunk({:user_component, "foo", %{"bar" => {:string, "x"}}, nil})

    assert String.contains?(compiled, ~s|bar: "x"|)
    assert String.contains?(compiled, "window.Rez.user_components.foo")
  end

  test "compile self-closing component with dynamic attribute" do
    compiled = C.compile_chunk({:user_component, "foo", %{"bar" => {:attr_expr, "player.name"}}, nil})

    assert String.contains?(compiled, "bar: evaluateExpression")
    assert String.contains?(compiled, "player.name")
  end

  test "compile container component includes sub_template and sub_content" do
    content = {:source_template, ["hello"]}
    compiled = C.compile_chunk({:user_component, "foo", %{}, content})

    assert String.contains?(compiled, "window.Rez.user_components.foo")
    assert String.contains?(compiled, "sub_template")
    assert String.contains?(compiled, "sub_content")
    assert String.contains?(compiled, ~s|No user @component foo defined!|)
  end

  test "component_assigns handles mixed attribute types" do
    # Test via compile_chunk since component_assigns is private
    compiled = C.compile_chunk({:user_component, "widget", %{
      "title" => {:string, "hello"},
      "count" => {:number, 42},
      "active" => {:boolean, true},
      "name" => {:attr_expr, "player.name"}
    }, nil})

    assert String.contains?(compiled, "window.Rez.user_components.widget")
  end
end
