defmodule Rez.AST.Slot do
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
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Slot do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(slot), to: NodeHelper
  defdelegate html_processor(slot, attr), to: NodeHelper

  def node_type(_slot), do: "slot"

  def js_ctor(slot) do
    NodeHelper.get_attr_value(slot, "$js_ctor", "RezSlot")
  end

  def process(slot, _) do
    slot
  end
end
