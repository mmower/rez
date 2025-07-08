defmodule Rez.AST.Object do
  @moduledoc """
  Defines the `%Object{}` structure. An Object is an author-defined structure
  and has no built-in meaning or runtime functionality.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Object do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(object), to: NodeHelper
  defdelegate html_processor(object, attr), to: NodeHelper

  def node_type(_object), do: "object"

  def js_ctor(object) do
    NodeHelper.get_attr_value(object, "$js_ctor", "RezObject")
  end

  def process(object, _node_map) do
    object
  end
end
