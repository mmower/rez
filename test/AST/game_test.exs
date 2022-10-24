defmodule Rez.AST.GameTest do
  use ExUnit.Case
  doctest Rez.AST.Game
  alias Rez.AST.Game, as: G

  test "sword is_a item" do
    game = %G{}
    game = G.add_child({:derive, "weapon", "item"}, game)
    game = G.add_child({:derive, "sword", "weapon"}, game)
    game = G.add_child({:derive, "long_sword", "sword"}, game)
    game = G.add_child({:derive, "long_sword", "one_handed"}, game)
    game = G.add_child({:derive, "two_handed_sword", "two_handed"}, game)
    game = G.add_child({:derive, "mace", "weapon"}, game)
    game = G.add_child({:derive, "potion", "item"}, game)
    game = G.add_child({:derive, "healing_potion", "potion"}, game)

    assert G.is_a(game, "sword", "weapon")
    assert G.is_a(game, "sword", "item")
    assert G.is_a(game, "potion", "item")
    refute G.is_a(game, "potion", "weapon")
    refute G.is_a(game, "healing_potion", "weapon")
    assert G.is_a(game, "long_sword", "one_handed")
    refute G.is_a(game, "long_sword", "two_handed")
    assert G.is_a(game, "two_handed_sword", "two_handed")
  end
end
