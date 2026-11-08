defmodule Rez.AST.Group do
  @moduledoc """
  `Rez.AST.Group` contains the `Group` struct.

  A `Group` selects a set of `Asset`s by type and tags. Membership is resolved
  at compile time by `Rez.Compiler.Phases.ResolveGroups`, which stores the
  matching asset ids in the group's `values` attribute. At runtime the group
  becomes a `RezList` with the same id.
  """
  defstruct status: :ok,
            # At runtime a RezList is created with the same id. We have a custom
            # js_initializer implementation in the AST Node module that creates it.
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Group do
  alias Rez.AST.Group
  alias Rez.AST.NodeHelper
  alias Rez.AST.ValueEncoder

  # Attributes used to resolve the group at compile time that have no meaning
  # at runtime
  @compile_time_attrs ["type", "include_tags", "exclude_tags"]

  defdelegate html_processor(group, attr), to: NodeHelper

  def node_type(_group), do: "group"

  def js_ctor(_group), do: raise("@group does not support a JS constructor!")

  def js_initializer(group) do
    attributes = Map.drop(group.attributes, @compile_time_attrs)

    ~s"""
    new RezList(
      "#{group.id}",
      #{ValueEncoder.encode_attributes(attributes)}
    )
    """
  end

  def process(%Group{} = group, _node_map) do
    group
  end
end
