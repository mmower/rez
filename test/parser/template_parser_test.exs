defmodule Rez.Parser.TemplateParserTest do
  use ExUnit.Case
  doctest Rez.Parser.TemplateExpressionParser

  alias Rez.Parser.TemplateParser, as: TP
  alias Rez.Parser.TemplateExpressionParser, as: EP

  # @tag :skip
  test "parses \\" do
    template = "\\"
    assert {:source_template, ["\\"]} = TP.parse(template)
  end

  # @tag :skip
  test "parses \\$" do
    template = "\\$"

    assert {:source_template, ["$"]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a plain string template" do
    template = """
    Here is a string, it has no interpolation.
    """

    assert {:source_template, [^template]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a string containing a single interpolation" do
    template = """
    Here is a string containing ${player.name} as an interpolation.
    """

    assert {:source_template,
            [
              "Here is a string containing ",
              {:interpolate, {:expression, {:bound_path, ["player", "name"]}, []}},
              " as an interpolation.\n"
            ]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a string with escaped interpolation" do
    template = """
    Here is a string without an \\${test} interpolation.
    """

    assert {:source_template, ["Here is a string without an ", "$", "{test} interpolation.\n"]} =
             TP.parse(template)
  end

  # @tag :skip
  test "parses a string with two interpolations" do
    template = """
    Interpolate both ${player.name} and ${player.age]} for completeness.
    """

    assert {:source_template,
            [
              "Interpolate both ",
              {:interpolate, {:expression, {:bound_path, ["player", "name"]}, []}},
              " and ",
              {:interpolate, {:expression, {:bound_path, ["player", "age"]}, []}},
              " for completeness.\n"
            ]} = TP.parse(template)
  end

  # @tag :skip
  test "fails to parse a broken interpolation" do
    template = """
    This string contains a broken ${interpolation
    """

    assert {:error, _} = TP.parse(template)
  end

  # tag :skip
  test "parses HTML correctly" do
    template = """
    <div data-card="block_header" class="card"><div class="columns box">
      <div class="column">  <h1 class="title">The Rain in Spain falls mainly on the plain!</h1>  </div></div>
    </div>
    """

    assert {:source_template,
            [
              "<div data-card=\"block_header\" class=\"card\"><div class=\"columns box\">\n  <div class=\"column\">  <h1 class=\"title\">The Rain in Spain falls mainly on the plain!</h1>  </div></div>\n</div>\n"
            ]} = TP.parse(template)
  end

  # @tag :skip
  test "can parse conditional" do
    expr = "player.health < 50"
    output = "<div>wounded</div>"
    input = "$if(#{expr}) -> {%#{output}%}"

    assert %{status: :ok, ast: {:conditional, [{^expr, {:source_template, [^output]}}]}} =
             Ergo.parse(TP.conditional(), input)
  end

  # @tag :skip
  test "parses conditional from template" do
    template = ~s"""
    <div>$if(player.health < 50) -> {%
      <div>Wounded</div>
    %}</div>
    """

    assert {:source_template,
            [
              "<div>",
              {:conditional,
               [{"player.health < 50", {:source_template, ["\n  <div>Wounded</div>\n"]}}]},
              "</div>\n"
            ]} = TP.parse(template)
  end

  # @tag :skip
  test "parses base template expression" do
    expression = "player.name"

    assert {:ok, {:expression, {:bound_path, ["player", "name"]}, []}} = EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with simple filter" do
    expression = "player.name | capitalize"

    assert {:ok, {:expression, {:bound_path, ["player", "name"]}, [{"capitalize", []}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with parameterised filter" do
    expression = "player.age | padleft: 2"

    assert {:ok, {:expression, {:bound_path, ["player", "age"]}, [{"padleft", [{:number, 2}]}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with multiple filters" do
    expression = "player.name | trim: 40 | capitalize | fooflify"

    assert {:ok,
            {:expression, {:bound_path, ["player", "name"]},
             [{"trim", [{:number, 40}]}, {"capitalize", []}, {"fooflify", []}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with multiple filter parameters" do
    assert {:ok,
            {:expression, {:bound_path, ["player", "name"]},
             [{"truncate", [{:number, 40}, {:string, "..."}]}]}} =
             EP.parse("player.name | truncate: 40, \"...\"")

    assert {:ok,
            {:expression, {:bound_path, ["card"]},
             [
               {"scene_switch",
                [{:string, "examine_player_scene"}, {:string, "Examine Yourself"}]}
             ]}} = EP.parse("card | scene_switch: \"examine_player_scene\", \"Examine Yourself\"")
  end

  # @tag :skip
  test "parses template expression that starts with a value" do
    assert {:ok,
            {:expression, {:string, "year"}, [{"pluralize", [{:bound_path, ["player", "age"]}]}]}} =
             EP.parse("\"year\" | pluralize: player.age")
  end

  # @tag :skip
  test "parses expression containing JS array" do
    assert {:ok,
            {:expression, {:bound_path, ["player", "age"]},
             [{"gte", [number: 18]}, {"bsel", [list: [string: "adult", string: "child"]]}]}} =
             EP.parse("player.age | gte: 18 | bsel: [\"adult\", \"child\"]")
  end
end
