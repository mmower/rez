defmodule Rez.AST.Scene do
  alias __MODULE__
  alias Rez.AST.{TemplateHelper, NodeHelper}
  alias Rez.Utils

  @moduledoc """
  `Rez.AST.Scene defines the `Scene` struct.

  A `Scene` represents a coherent piece of narrative that will be experienced
  by the player through one or more `Card`s.

  The `Scene` contains a layout that is wrapped around the content generated
  by `Card`s. For example a `Scene` might layout a storefront and use
  `Cards` to represent the process of browsing the store and buying items.

  Additionally a `Scene` can specify a `Location` to refer to objects that can
  be included or scenery that can be used to embellish.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            message: ""

  def process(%Scene{status: :ok, id: id} = scene) do
    case NodeHelper.get_attr_value(scene, "layout") do
      nil ->
        scene

      _ ->
        custom_css_class = NodeHelper.get_attr_value(scene, "css_class", "")
        css_classes = Utils.add_css_class("scene", custom_css_class)

        TemplateHelper.make_template(
          scene,
          "layout",
          fn html ->
            ~s(<div id="scene_#{id}" class="#{css_classes}">) <>
              html <>
              "</div>"
          end
        )
    end
  end

  def process(%Scene{} = scene), do: scene
end

defimpl Rez.AST.Node, for: Rez.AST.Scene do
  import Rez.AST.NodeValidator
  alias Rez.AST.Scene
  alias Rez.AST.NodeHelper

  def node_type(_scene), do: "scene"

  def js_ctor(scene) do
    NodeHelper.get_attr_value(scene, "js_ctor", "RezScene")
  end

  def js_initializer(scene) do
    NodeHelper.js_initializer(scene)
  end

  def default_attributes(_scene), do: %{}

  def pre_process(scene), do: scene

  def process(scene), do: Scene.process(scene)

  def children(_scene), do: []

  @content_expr ~r/\{\{[\{]?content[\}]?\}\}/

  def validators(_scene) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "layout",
        attribute_has_type?(
          :string,
          validate_value_matches?(
            @content_expr,
            "Expects layout attribute to include {{content}} or {{{content}}} expression!"
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
      attribute_if_present?(
        "location",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("location")
        )
      ),
      attribute_present?(
        "initial_card",
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
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
