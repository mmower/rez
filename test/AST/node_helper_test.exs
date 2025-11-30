defmodule Rez.AST.NodeHelperTest do
  use ExUnit.Case
  doctest Rez.AST.NodeHelper

  alias Rez.AST.NodeHelper
  alias Rez.AST.Game

  describe "build_type_map/1" do
    test "handles single game element" do
      game = %Game{id: "game", attributes: %{"name" => "Test"}}
      nodes = [game]

      type_map = NodeHelper.build_type_map(nodes)

      assert type_map["game"] == game
    end

    test "handles multiple game elements, returns last" do
      game1 = %Game{id: "game", attributes: %{"a" => 1}}
      game2 = %Game{id: "game", attributes: %{"b" => 2}}
      nodes = [game1, game2]

      type_map = NodeHelper.build_type_map(nodes)

      assert type_map["game"] == game2
    end
  end
end
