defmodule Rez.AST.Location do
  alias __MODULE__
  alias Rez.AST.{NodeHelper, TemplateHelper}
  alias Rez.Utils

  @moduledoc """
  `Rez.AST.Location` defines the `Location` struct.

  A `Location` describes an in-game location where a `Scene` can take place.

  `Location`s are optional but may make sense in map-driven games where a
  given `Scene` can occur in different `Location`s. The `Location` then
  can contain those things appropriate to the location being described.

  In particular `Item`s and `Actor`s may have a current location.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  def build_template(%Location{id: loc_id} = location) do
    NodeHelper.set_compiled_template_attr(
      location,
      "$content_template",
      TemplateHelper.compile_template(
        loc_id,
        NodeHelper.get_attr_value(location, "description", ""),
        NodeHelper.get_attr_value(location, "format", "markdown"),
        fn html ->
          html = TemplateHelper.process_links(html)
          custom_css_class = NodeHelper.get_attr_value(location, "css_class", "")
          css_classes = Utils.add_css_class("location", custom_css_class)
          ~s|<div id="loc_#{loc_id}" class="#{css_classes}">#{html}</div>|
        end
      )
    )
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Location do
  import Rez.AST.NodeValidator

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  alias Rez.AST.Attribute
  alias Rez.AST.Game
  alias Rez.AST.Location

  defdelegate js_initializer(location), to: NodeHelper

  def node_type(_location), do: "location"

  def js_ctor(location) do
    NodeHelper.get_attr_value(location, "$js_ctor", "RezLocation")
  end

  def default_attributes(_location), do: %{}

  def pre_process(location), do: location

  def process(location, node_map) do
    location
    |> NodeHelper.copy_attributes(node_map)
    |> Location.build_template()
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_location), do: []

  def validators(_location) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "name",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "alias",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("location")
        )
      ),
      attribute_if_present?(
        "to_label",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "in_label",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "container",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("inventory")
        )
      ),
      attribute_if_present?(
        "card",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("card")
        )
      ),
      attribute_if_present?(
        "description",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "exits",
        attribute_has_type?(
          :list,
          attribute_coll_of?(
            :elem_ref,
            attribute_list_references?("location")
          )
        )
      ),
      attribute_if_present?(
        "zone",
        attribute_has_type?(
          :list,
          attribute_passes?(fn %Attribute{value: value}, _node, %Game{id_map: id_map} = _game ->
            case value do
              [{:elem_ref, zone_id}, {:elem_ref, locator} | []] ->
                case Map.get(id_map, zone_id) do
                  {"zone", _, _} ->
                    :ok

                  {type, _, _} ->
                    {:error,
                     "'zone' attribute [#{zone_id} #{locator}] refers to #{type} not zone!"}

                  _ ->
                    {:error, "'zone' attribute [#{zone_id} #{locator}] zone was not found!"}
                end

              _ ->
                {:error, "'zone' attribute must be a two-element list [#zone-id #locator]"}
            end
          end)
        )
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
