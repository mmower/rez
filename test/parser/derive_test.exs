defmodule Rez.Parser.DeriveTest do
  use ExUnit.Case
  import Rez.Parser.Parser
  alias Rez.AST.{Game, TypeHierarchy}

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

    ctx = Ergo.parse(top_level(), input, data: %{source: source, id_map: %{}})
    assert %{status: :ok, ast: content, data: %{id_map: id_map}} = ctx

    game = Rez.Compiler.ParseSource.build_game(content, id_map)
    assert %Rez.AST.Game{} = game

    types = %{
      "great_sword" => MapSet.new(["sword", "two_handed"]),
      "long_sword" => MapSet.new(["sword", "one_handed"]),
      "sword" => MapSet.new(["weapon"]),
      "weapon" => MapSet.new(["item"])
    }

    assert %TypeHierarchy{
             is_a: ^types
           } = game.is_a

    assert Game.is_a(game, "great_sword", "item")
    assert Game.is_a(game, "long_sword", "one_handed")
    assert not Game.is_a(game, "great_sword", "one_handed")
  end
end
