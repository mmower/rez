defmodule Rez.AST.Inventory do
  @moduledoc """
  `Rez.AST.Inventory` contains the `Inventory` struct.

  An `Inventory` holds items in named *positions*, each declared by a nested
  `@contains` block (see `Rez.AST.Contains`) that names the `@slot` type
  controlling what the position accepts.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Inventory do
  alias Rez.AST.{Attribute, Contains, NodeHelper}

  defdelegate js_initializer(inventory), to: NodeHelper
  defdelegate html_processor(inventory, attr), to: NodeHelper

  def node_type(_inventory), do: "inventory"

  def js_ctor(inventory) do
    NodeHelper.get_attr_value(inventory, "$js_ctor", "RezInventory")
  end

  # Builds the `positions` attribute from the inventory's `@contains` blocks.
  # It is the only place an inventory keeps position state at runtime:
  #
  #   positions: {left_ring: {slot_id: "ring_slot", enabled: true, contents: ["silver_ring"]}}
  #
  # `contents` holds the items the position starts with. At runtime the
  # inventory empties each position and adds these items back through its
  # validated add path, so they fire events and apply effects.
  #
  # `process/2` runs again in ReprocessAST, by which time the `@contains`
  # blocks have been consumed, so it leaves `positions` alone.
  def process(inventory, _resources) do
    case NodeHelper.get_meta(inventory, "nested_contains", []) do
      [] -> inventory
      contains -> build_positions(inventory, contains)
    end
  end

  defp build_positions(inventory, contains) do
    positions =
      Map.new(contains, fn %Contains{id: pos_id} = pos ->
        {pos_id, Attribute.table(pos_id, position_table(pos))}
      end)

    inventory
    |> NodeHelper.set_table_attr("positions", positions)
    |> NodeHelper.set_meta("nested_contains", [])
  end

  defp position_table(%Contains{} = pos) do
    %{
      "slot_id" => Attribute.string("slot_id", ref_id(NodeHelper.get_attr_value(pos, "slot_id"))),
      "enabled" => Attribute.boolean("enabled", NodeHelper.get_attr_value(pos, "enabled", true)),
      "contents" =>
        Attribute.list(
          "contents",
          pos
          |> NodeHelper.get_attr_value("contents", [])
          |> Enum.map(&{:string, ref_id(&1)})
        )
    }
  end

  defp ref_id({:elem_ref, id}), do: id
  defp ref_id(id) when is_binary(id), do: id
end
