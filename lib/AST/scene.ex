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

  def build_template(%Scene{id: scene_id} = scene) do
    NodeHelper.set_compiled_template_attr(
      scene,
      "$layout_template",
      TemplateHelper.compile_template(
        scene_id,
        NodeHelper.get_attr_value(scene, "layout", ""),
        NodeHelper.get_attr_value(scene, "format", "markdown"),
        fn html ->
          # IO.puts("#{scene_id}:a #{String.length(html)}")
          html = TemplateHelper.process_links(html)
          # IO.puts("#{scene_id}:b #{String.length(html)}")
          custom_css_class = NodeHelper.get_attr_value(scene, "css_class", "")
          css_classes = Utils.add_css_class("scene", custom_css_class)
          ~s|<div id="scene_#{scene_id}" class="#{css_classes}">#{html}</div>|
        end
      )
    )
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Scene do
  import Rez.AST.NodeValidator
  alias Rez.AST.Scene
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(scene), to: NodeHelper

  def node_type(_scene), do: "scene"

  def js_ctor(scene) do
    NodeHelper.get_attr_value(scene, "js_ctor", "RezScene")
  end

  def default_attributes(_scene), do: %{}

  def pre_process(scene), do: scene

  def process(scene, node_map) do
    scene
    |> NodeHelper.copy_attributes(node_map)
    |> Scene.build_template()
  end

  def children(_scene), do: []

  @content_expr ~r/\$\{content\}/

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
