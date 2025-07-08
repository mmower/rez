defmodule Rez.AST.Behaviour do
  @moduledoc """
  `Rez.AST.Behaviour` contains the `Behaviour` struct and its `Node` implementation.

  A `Behaviour` is used to represent an action or condition used in a behaviour tree.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Behaviour do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(behaviour), to: NodeHelper
  defdelegate html_processor(behaviour, attr), to: NodeHelper

  def node_type(_behaviour), do: "behaviour"

  def js_ctor(behaviour) do
    NodeHelper.get_attr_value(behaviour, "$js_ctor", "RezBehaviour")
  end

  def process(behaviour, _node_map) do
    behaviour
  end
end
