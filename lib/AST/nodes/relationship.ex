defmodule Rez.AST.Relationship do
  @moduledoc """
  Specifies the Relationship AST node.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Relationship do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(relationship), to: NodeHelper
  defdelegate html_processor(relationship, attr), to: NodeHelper

  def node_type(_relationship), do: "relationship"

  def js_ctor(relationship) do
    NodeHelper.get_attr_value(relationship, "$js_ctor", "RezRelationship")
  end

  def process(relationship, _node_map) do
    relationship
  end
end
