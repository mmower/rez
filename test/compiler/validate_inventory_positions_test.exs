defmodule Rez.Compiler.ValidateInventoryPositionsTest do
  use ExUnit.Case

  alias Rez.AST.{Attribute, Contains, Inventory, Node, NodeHelper}
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ValidateInventoryPositions

  defp run(content) do
    ValidateInventoryPositions.run_phase(%Compilation{status: :ok, content: content})
  end

  defp contains(id, attrs \\ %{}) do
    %Contains{
      id: id,
      attributes: Map.put_new(attrs, "slot_id", Attribute.elem_ref("slot_id", "ring_slot"))
    }
  end

  defp inventory(id, positions, attrs \\ %{}) do
    %Inventory{id: id, attributes: attrs, metadata: %{"nested_contains" => positions}}
  end

  defp contents(item_ids) do
    Attribute.list("contents", Enum.map(item_ids, &{:elem_ref, &1}))
  end

  test "accepts valid positions and tags them for schema validation" do
    result =
      run([
        inventory("inv", [
          contains("left_ring", %{"contents" => contents(["silver_ring"])}),
          contains("right_ring", %{"enabled" => Attribute.boolean("enabled", false)})
        ])
      ])

    assert :ok = result.status
    [inv] = result.content

    assert Enum.all?(
             NodeHelper.get_meta(inv, "nested_contains"),
             &(NodeHelper.get_meta(&1, "alias_chain") == ["contains"])
           )
  end

  test "errors when an inventory has no positions" do
    result = run([inventory("inv", [])])
    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "at least one @contains"))
  end

  test "errors on duplicate position ids" do
    result = run([inventory("inv", [contains("p1"), contains("p1")])])
    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "duplicate @contains id(s): p1"))
  end

  test "errors on unknown @contains attributes" do
    result =
      run([inventory("inv", [contains("p1", %{"initial_contents" => contents(["x"])})])])

    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "unknown attribute(s) initial_contents"))
  end

  test "errors on position names beginning with _" do
    result = run([inventory("inv", [contains("_hidden")])])
    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "may not begin with _"))
  end

  test "errors when positions is authored" do
    result =
      run([
        inventory("inv", [contains("p1")], %{"positions" => Attribute.table("positions", %{})})
      ])

    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "positions is derived"))
  end

  test "errors when the legacy slots: attribute is used" do
    slots = Attribute.list("slots", [])
    result = run([inventory("inv", [contains("p1")], %{"slots" => slots})])
    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "slots: is no longer supported"))
  end

  test "errors when an item is placed in more than one position" do
    result =
      run([
        inventory("inv_a", [contains("p1", %{"contents" => contents(["ring"])})]),
        inventory("inv_b", [contains("p2", %{"contents" => contents(["ring"])})])
      ])

    assert :error = result.status
    assert Enum.any?(result.errors, &(&1 =~ "Item ring is placed in more than one"))
    assert Enum.any?(result.errors, &(&1 =~ "inv_a/p1, inv_b/p2"))
  end

  test "Inventory.process/2 builds the positions table" do
    inv =
      inventory("inv", [
        contains("left_ring", %{"contents" => contents(["silver_ring"])}),
        contains("right_ring", %{"enabled" => Attribute.boolean("enabled", false)})
      ])
      |> Node.process(%{})

    assert %Attribute{type: :table, value: positions} = inv.attributes["positions"]

    assert %Attribute{type: :table, value: left} = positions["left_ring"]
    assert left["slot_id"].value == "ring_slot"
    assert left["enabled"].value == true
    assert left["contents"].value == [{:string, "silver_ring"}]

    assert %Attribute{type: :table, value: right} = positions["right_ring"]
    assert right["enabled"].value == false
    assert right["contents"].value == []

    assert NodeHelper.get_meta(inv, "nested_contains") == []

    # Reprocessing (ReprocessAST) leaves the positions in place
    assert Node.process(inv, %{}).attributes["positions"] == inv.attributes["positions"]
  end
end
