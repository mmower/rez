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

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(inventory), to: NodeHelper

  def node_type(_inventory), do: "inventory"

  def js_ctor(inventory) do
    NodeHelper.get_attr_value(inventory, "$js_ctor", "RezInventory")
  end

  def default_attributes(_inventory),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0),
      "all_items" => Attribute.list("all_items", []),
      "items" => Attribute.table("items", %{}),
      "apply_effects" => Attribute.boolean("apply_effects", true)
    }

  def pre_process(inventory), do: inventory

  def process(inventory, %{by_id: node_map}) do
    inventory
    |> TemplateHelper.compile_template_attributes()
    |> NodeHelper.process_collection(:slots, node_map)
  end

  def children(_inventory), do: []

  def validators(_inventory) do
    [
      attribute_if_present?(
        "$init_after",
        attribute_has_type?(:list, attribute_coll_of?(:elem_ref))
      ),
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
        "initial_contents",
        attribute_has_type?(:table)
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
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
