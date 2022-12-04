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
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  def process(%Slot{} = slot) do
    slot
    |> set_defaults()
  end

  defp set_defaults(%Slot{} = slot) do
    slot
    |> NodeHelper.set_default_attr_value("capacity", 1, &NodeHelper.set_number_attr/3)
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Slot do
  alias Rez.AST.Slot
  import Rez.AST.NodeValidator

  def node_type(_slot), do: "slot"

  def pre_process(slot), do: slot

  def process(slot) do
    Slot.process(slot)
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
      )
    ]
  end
end
