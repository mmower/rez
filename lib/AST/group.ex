defmodule Rez.AST.Group do
  @moduledoc """
  `Rez.AST.Group` contains the `Group` struct.

  A `Group` represents a set of `Asset`s either specifying one or more
  asset ids or by specifying one or more tags.

  In the latter case the Group content will consist of those Assets that
  are tagged with the appropriate tag.
  """
  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            assets: %{},
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Group do
  alias Rez.AST.Group
  import Rez.AST.NodeValidator

  def node_type(_group), do: "group"

  def pre_process(group), do: group

  def process(%Group{attributes: %{"tags" => _tags}} = group) do
    group
  end

  def process(%Group{attributes: %{"content" => _content}} = group) do
    group
  end

  def process(%Group{attributes: %{"folder" => _folder}} = group) do
    group
  end

  def children(_group), do: []

  def validators(_group) do
    [
      attribute_one_of_present?(["tags", "content", "folder"], true),

      attribute_if_present?("tags",
        attribute_is_keyword_set?()),

      attribute_if_present?("content",
        attribute_has_type?(:list,
          attribute_not_empty_coll?(
            attribute_coll_of?([:elem_ref, :keyword])))),

      attribute_if_present?("folder",
        attribute_has_type?(:string))
    ]
  end
end
