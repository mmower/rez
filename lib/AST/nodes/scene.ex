defmodule Rez.AST.Scene do
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
            metadata: %{},
            message: "",
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Scene do
  alias Rez.AST.NodeHelper
  alias Rez.Utils

  defdelegate js_initializer(scene), to: NodeHelper

  def node_type(_scene), do: "scene"

  def js_ctor(scene) do
    NodeHelper.get_attr_value(scene, "$js_ctor", "RezScene")
  end

  def process(scene, _node_map) do
    scene
  end

  def html_processor(scene, "layout") do
    fn html ->
      custom_css_class = NodeHelper.get_attr_value(scene, "css_class", "")
      css_classes = Utils.add_css_class("rez-scene", custom_css_class)

      ~s|<div id="scene_#{scene.id}" data-scene="#{scene.id}" class="#{css_classes}">#{html}</div>|
    end
  end
end
