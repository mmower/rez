defmodule Rez.AST.Slot do
  alias __MODULE__
  alias Rez.AST.NodeHelper

  @moduledoc """
  `Rez.AST.Slot` defines the `Slot` struct.

  A `Slot` specifies a kind of `Item` that can be contained in an `Inventory`.

  For example an `Inventory` representing a wardrobe might have `Slot`s for
  coats, hats, trousers, shirts, and shoes. Only an `Item` that shares that
  `Slot` can be added to the `Inventory` in that slot.

  `Slot`s can be used to create rules covering which `Item`s can be combined in
  a single inventory. For example a "dress" slot might exclude `Items` from a
  "skirt" `Slot`.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  def set_defaults(%Slot{} = slot) do
    slot
    |> NodeHelper.set_default_attr_value("capacity", 1, &NodeHelper.set_number_attr/3)
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Slot do
  import Rez.AST.NodeValidator

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  alias Rez.AST.Slot

  defdelegate js_initializer(slot), to: NodeHelper

  def node_type(_slot), do: "slot"

  def js_ctor(slot) do
    NodeHelper.get_attr_value(slot, "js_ctor", "RezSlot")
  end

  def default_attributes(_slot), do: %{}

  def pre_process(slot), do: slot

  def process(slot, node_map) do
    slot
    |> Slot.set_defaults()
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_slot), do: []

  def validators(_slot) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "accepts",
        attribute_has_type?(:keyword)
      ),
      attribute_if_present?(
        "name",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "capacity",
        attribute_has_type?(:number)
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
