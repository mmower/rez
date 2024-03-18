defmodule Rez.AST.Scene do
  alias __MODULE__

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper
  alias Rez.Utils

  @moduledoc """
  `Rez.AST.Scene defines the `Scene` struct.

  A `Scene` represents a coherent piece of narrative that will be experienced
  by the player through one or more `Card`s.

  The `Scene` contains a layout that is wrapped around the content generated
  by `Card`s. For example a `Scene` might layout a storefront and use
  `Cards` to represent the process of browsing the store and buying items.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            message: ""

  defp compile_template(%{id: id} = scene) do
    NodeHelper.set_compiled_template_attr(
      scene,
      "$layout_template",
      TemplateHelper.compile_template(
        id,
        NodeHelper.get_attr_value(scene, "layout"),
        fn content ->
          custom_css_class = NodeHelper.get_attr_value(scene, "css_class", "")
          css_classes = Utils.add_css_class("scene", custom_css_class)

          ~s|<div id="scene_#{id}" data-scene="#{id}" class="#{css_classes}">#{content}</div>|
        end
      )
    )
  end

  defp remove_source_template(scene) do
    scene
    |> NodeHelper.delete_attr("layout")
    |> NodeHelper.delete_attr("layout_format")
  end

  def build_template(%Scene{status: :ok} = scene) do
    scene
    |> compile_template()
    |> remove_source_template()
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Scene do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  alias Rez.AST.Scene

  defdelegate js_initializer(scene), to: NodeHelper

  def node_type(_scene), do: "scene"

  def js_ctor(scene) do
    NodeHelper.get_attr_value(scene, "$js_ctor", "RezScene")
  end

  def default_attributes(_scene),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0),
      "current_card_id" => Attribute.string("current_card_id", ""),
      "layout_mode" => Attribute.keyword("layout_mode", "single"),
      "layout" => Attribute.source_template("layout", "${content}"),
      "layout_reverse" => Attribute.boolean("layout_reverse", false),
      "layout_separator" => Attribute.string("layout_separator", ""),
      "$running" => Attribute.boolean("$running", false)
    }

  def pre_process(scene), do: scene

  def process(scene, %{by_id: node_map}) do
    scene
    |> NodeHelper.copy_attributes(node_map)
    |> Scene.build_template()
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_scene), do: []

  @content_expr ~s|${content}|

  def validators(_scene) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "layout",
        attribute_has_type?(
          :source_template,
          validate_value_contains?(
            @content_expr,
            "Scene layout attribute is expected to include a ${content} expression!"
          )
        )
      ),
      attribute_present?(
        "layout_mode",
        attribute_has_type?(
          :keyword,
          attribute_value_is_one_of?(["single", "stack"])
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
      attribute_present?(
        "initial_card_id",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("card")
        )
      ),
      attribute_if_present?(
        "on_init",
        attribute_has_type?(:function)
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
        "on_interrupt",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_resume",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_render",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_start_card",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_finish_card",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
