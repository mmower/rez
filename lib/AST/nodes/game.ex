defmodule Rez.AST.Game do
  @moduledoc """
  `Rez.AST.Game` contains the `Game` struct that is the root object for all
  game content.
  """
  alias __MODULE__

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: "game",
            attributes: %{},
            metadata: %{},
            validation: nil

  def get_aliases_and_mixins(%Game{} = game, node) do
    base_element = Node.node_type(node)
    initial_alias = NodeHelper.get_attr_value(node, "$alias")

    {chain, mixins} = build_chain(game, initial_alias, base_element)
    {List.flatten(chain), mixins}
  end

  defp build_chain(_game, nil, base_element), do: {[base_element], MapSet.new()}

  defp build_chain(%{elems: elems} = game, current_elem, base_element) do
    case Map.get(elems, current_elem) do
      {parent_element, {:mixins, mixin_list}} ->
        current_mixins = MapSet.new(mixin_list)

        case Map.get(elems, parent_element) do
          nil ->
            {[base_element, current_elem], current_mixins}

          {_next_element, _next_mixins} ->
            {parent_chain, parent_mixins} = build_chain(game, parent_element, base_element)
            {parent_chain ++ [current_elem], MapSet.union(parent_mixins, current_mixins)}
        end

      nil ->
        {[base_element, current_elem], MapSet.new()}
    end
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Game do
  alias Rez.Utils
  alias Rez.AST.NodeHelper
  alias Rez.AST.Game

  defdelegate js_initializer(game), to: NodeHelper

  def node_type(_game), do: "game"

  def js_ctor(game) do
    NodeHelper.get_attr_value(game, "$js_ctor", "RezGame")
  end

  def process(%Game{} = game, _), do: game

  def html_processor(game, "layout") do
    fn html ->
      custom_css_class = NodeHelper.get_attr_value(game, "css_class", "")
      css_classes = Utils.add_css_class("rez-game", custom_css_class)

      ~s|<div id="game" data-game=true class="#{css_classes}">#{html}</div>|
    end
  end

  def html_processor(game, attr), do: NodeHelper.html_processor(game, attr)
end
