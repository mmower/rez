defmodule Rez.Parser.TemplateParserTest do
  use ExUnit.Case

  alias Rez.Parser.TemplateParser, as: TP
  alias Rez.Parser.TemplateExpressionParser, as: EP

  # @tag :skip
  test "parses \\" do
    template = "\\"
    assert {:template, ["\\"]} = TP.parse(template)
  end

  # @tag :skip
  test "parses \\$" do
    template = "\\$"

    assert {:template, ["$"]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a plain string template" do
    template = """
    Here is a string, it has no interpolation.
    """

    assert {:template, [^template]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a string containing a single interpolation" do
    template = """
    Here is a string containing ${player.name} as an interpolation.
    """

    assert {:template,
            [
              "Here is a string containing ",
              {:interpolate, {:expression, {:lookup, "player", "name"}, []}},
              " as an interpolation.\n"
            ]} = TP.parse(template)
  end

  # @tag :skip
  test "parses a string with escaped interpolation" do
    template = """
    Here is a string without an \\${test} interpolation.
    """

    assert {:template, ["Here is a string without an ", "$", "{test} interpolation.\n"]} =
             TP.parse(template)
  end

  # @tag :skip
  test "parses a string with two interpolations" do
    template = """
    Interpolate both ${player.name} and ${player.age]} for completeness.
    """

    assert {:template,
            [
              "Interpolate both ",
              {:interpolate, {:expression, {:lookup, "player", "name"}, []}},
              " and ",
              {:interpolate, {:expression, {:lookup, "player", "age"}, []}},
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

  # @tag :skip
  test "parses base template expression" do
    expression = "player.name"

    assert {:ok, {:expression, {:lookup, "player", "name"}, []}} = EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with simple filter" do
    expression = "player.name | capitalize"

    assert {:ok, {:expression, {:lookup, "player", "name"}, [{"capitalize", []}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with parameterised filter" do
    expression = "player.age | padleft: 2"

    assert {:ok, {:expression, {:lookup, "player", "age"}, [{"padleft", [{:number, 2}]}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with multiple filters" do
    expression = "player.name | trim: 40 | capitalize | fooflify"

    assert {:ok,
            {:expression, {:lookup, "player", "name"},
             [{"trim", [{:number, 40}]}, {"capitalize", []}, {"fooflify", []}]}} =
             EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression with multiple filter parameters" do
    expression = "player.name | truncate: 40, \"...\""

    assert {:ok,
            {:expression, {:lookup, "player", "name"},
             [{"truncate", [{:number, 40}, {:string, "..."}]}]}} = EP.parse(expression)
  end

  # @tag :skip
  test "parses template expression that starts with a value" do
    assert {:ok, {:expression, {:string, "year"}, [{"pluralize", [{:lookup, "player", "age"}]}]}} =
             EP.parse("\"year\" | pluralize: player.age")
  end
end
