defmodule Rez.AST.Item do
  alias __MODULE__

  alias Rez.AST.NodeHelper
  alias Rez.AST.TypeHierarchy

  @moduledoc """
  `Rez.AST.Item` defines the `Item` struct.

  An `Item` specifies some in-game artifact that the player can acquire and
  that will be part of an inventory.

  `Item`s do not necessarily have to refer to physical items. A "spell" could
  be an item that would live in an `Inventory` representing a spell book.

  Each `Item` has a category to match to a compatible `Inventory` that has
  the same category. Each `Item` also defines the slot it can sit in, within
  that `Inventory`. `Slot`s are for `Item`s that are interchangable with each
  other.
  """
  defstruct status: :ok,
            game_element: true,
            id: nil,
            position: {nil, 0, 0},
            attributes: %{},
            metadata: %{},
            validation: nil

  def add_types_as_tags(%Item{} = item, %TypeHierarchy{} = type_hierarchy) do
    case NodeHelper.get_attr_value(item, "type") do
      nil ->
        item

      type ->
        tags =
          case NodeHelper.get_attr(item, "tags") do
            nil ->
              MapSet.new()

            %{value: value} ->
              value
          end

        expanded_types =
          [type | TypeHierarchy.expand(type_hierarchy, type)]
          |> Enum.map(fn type -> {:keyword, type} end)

        tags =
          Enum.reduce(expanded_types, tags, fn tag, tags ->
            MapSet.put(tags, tag)
          end)

        NodeHelper.set_set_attr(item, "tags", tags)
    end
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Item do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(item), to: NodeHelper
  defdelegate html_processor(item, attr), to: NodeHelper

  def node_type(_item), do: "item"

  def js_ctor(item) do
    NodeHelper.get_attr_value(item, "$js_ctor", "RezItem")
  end

  def process(item, _node_map) do
    item
  end
end
