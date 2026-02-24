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

  def process(inventory, _resources) do
    slots = NodeHelper.get_attr_value(inventory, "slots")

    Enum.reduce(slots, inventory, fn {:list_binding, {prefix, _source}}, inventory ->
      NodeHelper.set_list_attr(inventory, "#{prefix}_contents", [])
    end)
  end
end
