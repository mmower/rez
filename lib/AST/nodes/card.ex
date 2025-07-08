defmodule Rez.AST.Card do
  @moduledoc """
  `Rez.AST.Card` defines the `Card` struct.

  A `Card` represents a unit of content specified as markup that contains
  also links representing the actions the player can take.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper
  alias Rez.Utils

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            html: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Card do
  alias Rez.Utils

  alias Rez.AST.NodeHelper

  alias Rez.AST.Card

  def node_type(_card), do: "card"

  defdelegate js_initializer(card), to: NodeHelper

  def js_ctor(card) do
    NodeHelper.get_attr_value(card, "$js_ctor", "RezCard")
  end

  def process(%Card{status: :ok} = card, _node_map) do
    card
  end

  def process(card, _), do: card

  def html_processor(card, "content") do
    fn html ->
      if NodeHelper.get_attr_value(card, "$suppress_wrapper", false) do
        html
      else
        custom_css_class = NodeHelper.get_attr_value(card, "css_class", "")
        css_classes = Utils.add_css_class("rez-front-face", custom_css_class)

        ~s|<div id="card_#{card.id}" data-card="#{card.id}" class="#{css_classes}">#{html}</div>|
      end
    end
  end

  def html_processor(card, "flipped_content") do
    fn html ->
      if NodeHelper.get_attr_value(card, "$suppress_wrapper", false) do
        html
      else
        custom_css_class = NodeHelper.get_attr_value(card, "css_class", "")
        css_classes = Utils.add_css_class("rez-flipped-face", custom_css_class)

        ~s|<div data-card="#{card.id}" data-card="#{card.id}" data-flipped=true class="#{css_classes}">#{html}</div>|
      end
    end
  end

  def html_processor(card, attr) do
    NodeHelper.html_processor(card, attr)
  end
end
