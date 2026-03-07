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

  def html_processor(card, attr) do
    faces = NodeHelper.get_attr_value(card, "faces", MapSet.new([:content, :back]))
    face_names = faces |> Enum.map(fn
      {:keyword, name} -> name
      name -> to_string(name)
    end) |> MapSet.new()

    if MapSet.member?(face_names, attr) do
      fn html ->
        if NodeHelper.get_attr_value(card, "$suppress_wrapper", false) do
          html
        else
          custom_css_class = NodeHelper.get_attr_value(card, "css_class", "")
          css_classes = Utils.add_css_class("rez-face-#{attr} rez-evented", custom_css_class)
          id_attr = if attr == "content", do: ~s| id="card_#{card.id}"|, else: ""

          ~s|<div#{id_attr} data-card="#{card.id}" data-face="#{attr}" class="#{css_classes}">#{html}</div>|
        end
      end
    else
      NodeHelper.html_processor(card, attr)
    end
  end
end
