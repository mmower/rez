defmodule Rez.AST.Object do
  @moduledoc """
  Defines the `%Object{}` structure. An Object is an author-defined structure
  and has no built-in meaning or runtime functionality.
  """

  defstruct [
    status: :ok,
    position: {nil, 0, 0},
    id: nil,
    attributes: %{},
  ]
end

defimpl Rez.AST.Node, for: Rez.AST.Object do
  def node_type(_object), do: "object"
  def pre_process(object), do: object
  def process(object), do: object
  def children(_object), do: []
  def validators(_object), do: []
end
