defmodule Rez.AST.Card do
  @moduledoc """
  `Rez.AST.Card` defines the `Card` struct.

  A `Card` represents a unit of content specified as markup that contains
  also links representing the actions the player can take.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper
  alias Rez.Utils

  defstruct status: :ok,
            game_element: true,
            id: nil,
            html: nil,
            attributes: %{},
            position: {nil, 0, 0}

  def build_template(%Card{id: card_id} = card) do
    NodeHelper.set_compiled_template_attr(
      card,
      "$content_template",
      TemplateHelper.compile_template(
        card_id,
        NodeHelper.get_attr_value(card, "content", ""),
        fn html ->
          if NodeHelper.get_attr_value(card, "$suppress_wrapper", false) do
            html
          else
            custom_css_class = NodeHelper.get_attr_value(card, "css_class", "")
            css_classes = Utils.add_css_class("rez-front-face", custom_css_class)

            ~s|<div id="card_#{card_id}" data-card="#{card_id}" class="#{css_classes}">#{html}</div>|
          end
        end
      )
    )
  end

  def build_flipped_template(%Card{id: card_id} = card) do
    NodeHelper.set_compiled_template_attr(
      card,
      "$flipped_template",
      TemplateHelper.compile_template(
        card_id,
        NodeHelper.get_attr_value(card, "flipped_content", ""),
        fn html ->
          if NodeHelper.get_attr_value(card, "$suppress_wrapper", false) do
            html
          else
            custom_css_class = NodeHelper.get_attr_value(card, "css_class", "")
            css_classes = Utils.add_css_class("rez-flipped-face", custom_css_class)

            ~s|<div data-card="#{card_id}" data-card="#{card_id}" data-flipped=true class="#{css_classes}">#{html}</div>|
          end
        end
      )
    )
  end

  def build_templates(%Card{} = card) do
    card
    |> build_template()
    |> build_flipped_template()
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Card do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  alias Rez.AST.Card

  def node_type(_card), do: "card"

  defdelegate js_initializer(card), to: NodeHelper

  def js_ctor(card) do
    NodeHelper.get_attr_value(card, "$js_ctor", "RezCard")
  end

  def default_attributes(_card),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0)
    }

  def pre_process(card), do: card

  def process(%Card{status: :ok} = card, %{by_id: node_map}) do
    card
    |> NodeHelper.copy_attributes(node_map)
    |> Card.build_templates()
    |> TemplateHelper.compile_template_attributes()
  end

  def process(card, _), do: card

  def children(_card), do: []

  def validators(_card) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      ),
      attribute_present?(
        "content",
        attribute_has_type?(:source_template)
      ),
      attribute_if_present?(
        "flipped_content",
        attribute_has_type?(:source_template)
      ),
      attribute_if_present?(
        "bindings",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:list_binding)
        )
      ),
      attribute_if_present?(
        "blocks",
        attribute_has_type?(
          :list,
          attribute_coll_of?(
            :elem_ref,
            attribute_list_references?("card")
          )
        )
      ),
      attribute_if_present?(
        "css_class",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "on_start",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_finish",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_render",
        attribute_has_type?(:function)
      )
    ]
  end
end
