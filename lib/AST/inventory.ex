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
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Inventory do
  import Rez.AST.NodeValidator
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(inventory), to: NodeHelper

  def node_type(_inventory), do: "inventory"

  def js_ctor(inventory) do
    NodeHelper.get_attr_value(inventory, "js_ctor", "RezInventory")
  end

  def default_attributes(_inventory), do: %{}

  def pre_process(inventory) do
    inventory
    |> NodeHelper.set_boolean_attr("apply_effects", false)
  end

  def process(inventory, node_map) do
    inventory
    |> NodeHelper.copy_attributes(node_map)
    |> NodeHelper.process_collection(:slots, node_map)
  end

  def children(_inventory), do: []

  def validators(_inventory) do
    [
      attribute_present?(
        "slots",
        attribute_has_type?(
          :set,
          attribute_not_empty_coll?(
            attribute_coll_of?(
              :elem_ref,
              attribute_list_references?("slot")
            )
          )
        )
      ),
      attribute_if_present?(
        "apply_effects",
        attribute_has_type?(:boolean)
      ),
      attribute_if_present?(
        "owner",
        attribute_has_type?(:elem_ref)
      ),
      attribute_if_present?(
        "on_insert",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_remove",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
