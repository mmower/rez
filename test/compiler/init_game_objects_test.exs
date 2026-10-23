defmodule Rez.Compiler.Phases.InitGameObjectsTest do
  use ExUnit.Case

  alias Rez.Compiler.Phases.CreateRuntime

  defp global_elem(id) do
    %Rez.AST.Actor{
      id: id,
      game_element: true,
      attributes: %{"$global" => Rez.AST.Attribute.boolean("$global", true)}
    }
  end

  defp render(elements) do
    CreateRuntime.init_game_objects(
      game: %Rez.AST.Game{id: "game"},
      game_elements: elements,
      generators: [],
      shared_fn_decls: ""
    )
  end

  test "collects $global elements into a bindings map built once at init" do
    js = render([global_elem("player"), %Rez.AST.Actor{id: "npc", game_element: true}, global_elem("hero")])

    assert js =~ ~s(globalBindings["player"] = el;)
    assert js =~ ~s(globalBindings["hero"] = el;)
    refute js =~ ~s(globalBindings["npc"])
    assert js =~ "game.setGlobalBindings(globalBindings);"
    refute js =~ "globalBindingIds"
  end
end
