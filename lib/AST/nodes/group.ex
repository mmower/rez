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
            attributes: %{},
            metadata: %{},
            assets: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Group do
  alias Rez.AST.Group
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(group), to: NodeHelper
  defdelegate html_processor(group, attr), to: NodeHelper

  def node_type(_group), do: "group"

  def js_ctor(group) do
    NodeHelper.get_attr_value(group, "$js_ctor", "RezGroup")
  end

  def process(%Group{} = group, _node_map) do
    group
  end
end
