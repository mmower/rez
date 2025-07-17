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
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(inventory), to: NodeHelper
  defdelegate html_processor(inventory, attr), to: NodeHelper

  def node_type(_inventory), do: "inventory"

  def js_ctor(inventory) do
    NodeHelper.get_attr_value(inventory, "$js_ctor", "RezInventory")
  end

  def process(inventory, %{id_map: id_map}) do
    # Add attributes corresponding to the slots
    slots = NodeHelper.get_attr_value(inventory, "slots")

    Enum.reduce(slots, inventory, fn {:elem_ref, slot_id}, inventory ->
      slot = Map.get(id_map, slot_id)
      accessor = NodeHelper.get_attr_value(slot, "accessor")

      # We don't put in an id but we create an attribute with a placeholder to
      # ensure the shape of the inventory is set at the beginning
      NodeHelper.set_elem_ref_attr(inventory, "#{accessor}_id", "")
      # This attribute will hold the contents for the given slot
      NodeHelper.set_list_attr(inventory, "#{accessor}_contents", [])
      # We anticipate an attribute "accessor_initial_content" if the
      # slot is to be prefilled
    end)
  end
end
