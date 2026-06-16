defmodule Rez.Compiler.ExpandInventorySlotsTest do
  use ExUnit.Case

  alias Rez.AST.{Attribute, Contains, Inventory, Slot}
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ExpandInventorySlots

  defp make_compilation(content) do
    %Compilation{status: :ok, content: content}
  end

  defp engine_slot do
    %Slot{
      id: "engine_slot",
      attributes: %{
        "accepts" => Attribute.keyword("accepts", "engine")
      }
    }
  end

  defp contains(id, attrs) do
    %Contains{id: id, attributes: attrs}
  end

  test "derives slots:, *_contents prefixes and initial_* attrs from @contains positions" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{},
      metadata: %{
        "nested_contains" => [
          contains("left_engine", %{
            "slot_id" => Attribute.elem_ref("slot_id", "engine_slot"),
            "initial_contents" => Attribute.list("initial_contents", [{:elem_ref, "fast_engine"}])
          }),
          contains("right_engine", %{
            "slot_id" => Attribute.elem_ref("slot_id", "engine_slot")
          })
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :ok = result.status

    [_slot, ship_inv] = result.content

    assert %Inventory{id: "ship_inv"} = ship_inv
    refute is_struct(Enum.at(result.content, 1), Contains)
    assert Enum.all?(result.content, &(!is_struct(&1, Contains)))

    assert %Attribute{type: :list, value: slots} = ship_inv.attributes["slots"]

    assert slots == [
             {:list_binding,
              {"left_engine", {:source, false, {:elem_ref, "engine_slot"}}}},
             {:list_binding,
              {"right_engine", {:source, false, {:elem_ref, "engine_slot"}}}}
           ]

    assert %Attribute{type: :list, value: [{:elem_ref, "fast_engine"}]} =
             ship_inv.attributes["initial_left_engine"]

    refute Map.has_key?(ship_inv.attributes, "initial_right_engine")

    assert ship_inv.metadata["nested_contains"] == []
  end

  test "hoists initial_enabled to initial_{prefix}_enabled" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{},
      metadata: %{
        "nested_contains" => [
          contains("left_engine", %{
            "slot_id" => Attribute.elem_ref("slot_id", "engine_slot"),
            "initial_enabled" => Attribute.boolean("initial_enabled", false)
          })
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :ok = result.status
    [_slot, ship_inv] = result.content

    assert %Attribute{type: :boolean, value: false} =
             ship_inv.attributes["initial_left_engine_enabled"]
  end

  test "passes through inventories with no @contains positions unchanged" do
    inventory = %Inventory{id: "empty_inv", attributes: %{}, metadata: %{}}

    result = ExpandInventorySlots.run_phase(make_compilation([inventory]))

    assert :ok = result.status
    assert [^inventory] = result.content
  end

  test "errors when slots: is authored alongside @contains children" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{
        "slots" => Attribute.list("slots", [])
      },
      metadata: %{
        "nested_contains" => [
          contains("left_engine", %{"slot_id" => Attribute.elem_ref("slot_id", "engine_slot")})
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "ship_inv"
    assert error =~ "slots:"
  end

  test "errors on duplicate @contains ids within the same inventory" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{},
      metadata: %{
        "nested_contains" => [
          contains("engine", %{"slot_id" => Attribute.elem_ref("slot_id", "engine_slot")}),
          contains("engine", %{"slot_id" => Attribute.elem_ref("slot_id", "engine_slot")})
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "ship_inv"
    assert error =~ "duplicate"
    assert error =~ "engine"
  end

  test "errors when @contains is missing slot_id" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{},
      metadata: %{
        "nested_contains" => [
          contains("left_engine", %{})
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "ship_inv"
    assert error =~ "left_engine"
    assert error =~ "slot_id"
  end

  test "errors when @contains slot_id does not refer to a @slot" do
    inventory = %Inventory{
      id: "ship_inv",
      attributes: %{},
      metadata: %{
        "nested_contains" => [
          contains("left_engine", %{
            "slot_id" => Attribute.elem_ref("slot_id", "not_a_slot")
          })
        ]
      }
    }

    result = ExpandInventorySlots.run_phase(make_compilation([engine_slot(), inventory]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "ship_inv"
    assert error =~ "left_engine"
    assert error =~ "slot_id"
  end
end
