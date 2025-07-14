defmodule Rez.Parser.DeriveTest do
  use ExUnit.Case
  import Rez.Parser.Parser

  alias Rez.Compiler.Compilation

  alias Rez.AST.TypeHierarchy

  def dummy_source(input, file \\ "test.rez", base_path \\ ".") do
    lines = String.split(input, ~r/\n/, trim: true)
    section = LogicalFile.Section.new(file, 1..Enum.count(lines), lines, 0)
    LogicalFile.assemble(base_path, [section])
  end

  test "derive from multiple roots" do
    input = """
      @game {}
      @derive :weapon :item
      @derive :sword :weapon
      @derive :long_sword :sword
      @derive :long_sword :one_handed
      @derive :great_sword :sword
      @derive :great_sword :two_handed
    """

    source = dummy_source(input)

    assert %{status: :ok, ast: content} =
             Ergo.parse(top_level(), input, data: %{source: source, id_map: %{}})

    %{type_hierarchy: %TypeHierarchy{} = type_hierarchy} =
      Rez.Compiler.Phases.BuildSchema.run_phase(%Compilation{content: content})

    # assert %TypeHierarchy{} = content.game = Rez.Compiler.ParseSource.build_game(content, id_map)
    # assert %Rez.AST.Game{} = game

    # types = %{
    #   "great_sword" => MapSet.new(["sword", "two_handed"]),
    #   "long_sword" => MapSet.new(["sword", "one_handed"]),
    #   "sword" => MapSet.new(["weapon"]),
    #   "weapon" => MapSet.new(["item"])
    # }

    # assert %TypeHierarchy{
    #          is_a: ^types
    #        } = game.is_a

    assert TypeHierarchy.is_a(type_hierarchy, "great_sword", "item")
    assert TypeHierarchy.is_a(type_hierarchy, "long_sword", "one_handed")
    assert not TypeHierarchy.is_a(type_hierarchy, "great_sword", "one_handed")
  end
end
