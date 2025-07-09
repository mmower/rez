defmodule Rez.AST.TypeHierarchyTest do
  use ExUnit.Case
  doctest Rez.AST.TypeHierarchy

  alias Rez.Compiler.Compilation
  alias Rez.AST.TypeHierarchy

  test "sword is_a item" do
    %{type_hierarchy: type_hierarchy} =
      %Compilation{
        content: [
          %Rez.AST.Derive{tag: "weapon", parent: "item"},
          %Rez.AST.Derive{tag: "sword", parent: "weapon"},
          %Rez.AST.Derive{tag: "long_sword", parent: "sword"},
          %Rez.AST.Derive{tag: "long_sword", parent: "one_handed"},
          %Rez.AST.Derive{tag: "two_handed_sword", parent: "two_handed"},
          %Rez.AST.Derive{tag: "mace", parent: "weapon"},
          %Rez.AST.Derive{tag: "potion", parent: "item"},
          %Rez.AST.Derive{tag: "healing_potion", parent: "potion"}
        ]
      }
      |> Rez.Compiler.Phases.CreateTypeHierarchy.run_phase()

    assert TypeHierarchy.is_a(type_hierarchy, "sword", "weapon")
    assert TypeHierarchy.is_a(type_hierarchy, "sword", "item")
    assert TypeHierarchy.is_a(type_hierarchy, "potion", "item")
    refute TypeHierarchy.is_a(type_hierarchy, "potion", "weapon")
    assert TypeHierarchy.is_a(type_hierarchy, "healing_potion", "item")
    refute TypeHierarchy.is_a(type_hierarchy, "healing_potion", "weapon")
    assert TypeHierarchy.is_a(type_hierarchy, "long_sword", "one_handed")
    refute TypeHierarchy.is_a(type_hierarchy, "long_sword", "two_handed")
    assert TypeHierarchy.is_a(type_hierarchy, "two_handed_sword", "two_handed")
  end
end
