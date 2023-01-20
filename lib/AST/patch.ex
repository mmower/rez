defmodule Rez.AST.Patch do
  @moduledoc """
  `Rez.AST.Patch` contains the `Patch` struct and its `Node` implementation.

  A `Patch` is used to represent a new method added to a class at runtime.
  """

  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Patch do
  import Rez.AST.NodeValidator

  def node_type(_patch), do: "patch"

  def pre_process(patch), do: patch

  def process(patch), do: patch

  def children(_patch), do: []

  def validators(_patch) do
    [
      attribute_present?("class", attribute_has_type?(:string)),
      attribute_present?("method", attribute_has_type?(:string)),
      attribute_present?("impl", attribute_has_type?(:function))
    ]
  end
end
