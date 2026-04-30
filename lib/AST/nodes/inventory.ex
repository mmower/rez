defmodule Rez.AST.Inventory do
  @moduledoc """
  `Rez.AST.Inventory` contains the `Inventory` struct.

  An `Inventory` represents the idea of a container that uses `Slots` to
  control and reflect what it contains.
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
  alias Rez.AST.{Attribute, NodeHelper}

  defdelegate js_initializer(inventory), to: NodeHelper
  defdelegate html_processor(inventory, attr), to: NodeHelper

  def node_type(_inventory), do: "inventory"

  def js_ctor(inventory) do
    NodeHelper.get_attr_value(inventory, "$js_ctor", "RezInventory")
  end

  def process(inventory, _resources) do
    slots = NodeHelper.get_attr_value(inventory, "slots")

    inventory =
      Enum.reduce(slots, inventory, fn {:list_binding, {prefix, _source}}, inv ->
        NodeHelper.set_list_attr(inv, "#{prefix}_contents", [])
      end)

    slot_table =
      Enum.reduce(slots, %{}, fn {:list_binding, {prefix, source}}, acc ->
        Map.put(acc, prefix, Attribute.string(prefix, extract_slot_id(source)))
      end)

    NodeHelper.set_table_attr(inventory, "slots", slot_table)
  end

  defp extract_slot_id({:source, _deref, {:elem_ref, id}}), do: id
  defp extract_slot_id({:literal, {:string, id}}), do: id
end
