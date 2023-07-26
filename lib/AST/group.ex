defmodule Rez.AST.Group do
  @moduledoc """
  `Rez.AST.Group` contains the `Group` struct.

  A `Group` represents a set of `Asset`s either specifying one or more
  asset ids or by specifying one or more tags.

  In the latter case the Group content will consist of those Assets that
  are tagged with the appropriate tag.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            assets: %{},
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Group do
  import Rez.AST.NodeValidator
  alias Rez.AST.Group
  alias Rez.AST.NodeHelper

  def node_type(_group), do: "group"

  def js_ctor(group) do
    NodeHelper.get_attr_value(group, "js_ctor", "RezGroup")
  end

  def js_initializer(group) do
    NodeHelper.js_initializer(group)
  end

  def default_attributes(_group), do: %{}

  def pre_process(group), do: group

  def process(%Group{} = group), do: group

  def children(_group), do: []

  def validators(_group) do
    [
      attribute_present?(
        "type",
        attribute_value_is_one_of?(["image", "audio", "video"])
      ),
      attribute_one_of_present?(["include_tags", "exclude_tags"], true),
      attribute_if_present?(
        "include_tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "exclude_tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
