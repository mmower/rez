defmodule Rez.AST.Item do
  alias __MODULE__

  alias Rez.Utils

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper
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

  def build_template(%Item{id: item_id} = item) do
    NodeHelper.set_compiled_template_attr(
      item,
      "$content_template",
      TemplateHelper.compile_template(
        item_id,
        NodeHelper.get_attr_value(item, "description", ""),
        fn html ->
          custom_css_class = NodeHelper.get_attr_value(item, "css_class", "")
          css_classes = Utils.add_css_class("item", custom_css_class)

          ~s|<div id="item_#{item_id}" data-item="#{item_id}" class="#{css_classes}">#{html}</div>|
        end
      )
    )
  end

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
          [type | TypeHierarchy.fan_out(type_hierarchy, type)]
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
    # |> Item.build_template()
    # |> TemplateHelper.compile_template_attributes()
  end

  # def validators(item) do
  #   [

  #     node_passes?(fn node, %Game{slots: slots} = game ->
  #       case find_attribute(game, item, "type") do
  #         nil ->
  #           {:error, "No 'type' attribute available for #{Node.node_type(node)}/#{node.id}"}

  #         %Attribute{value: type} ->
  #           accepted_type_specs =
  #             slots
  #             |> Enum.map(fn {_slot_id, slot} -> NodeHelper.get_attr_value(slot, "accepts") end)
  #             # We need to filter the results because if a slot is missing its
  #             # accepts: attribute we'll get a nil in the results but this will
  #             # cause an exception before the item can finish validating and
  #             # validation errors can be reported
  #             |> Enum.filter(&(!is_nil(&1)))
  #             |> Enum.uniq()

  #           case Enum.any?(accepted_type_specs, fn accepted_type
  #                                                  when is_binary(accepted_type) ->
  #                  Game.is_a(game, type, accepted_type)
  #                end) do
  #             true -> :ok
  #             false -> {:error, "No slot found accepting type #{type} for item #{item.id}"}
  #           end
  #       end
  #     end)
  #   ]
  # end
end
