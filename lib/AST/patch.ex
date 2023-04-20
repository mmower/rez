defmodule Rez.AST.Patch do
  @moduledoc """
  `Rez.AST.Patch` contains the `Patch` struct and its `Node` implementation.

  A `Patch` is used to represent a new method added to a class at runtime.
  """

  alias __MODULE__

  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  def type(%Patch{} = patch) do
    case {NodeHelper.has_attr?(patch, "function"), NodeHelper.has_attr?(patch, "method")} do
      {true, false} ->
        :function

      {false, true} ->
        :method
    end
  end

  def object(%Patch{} = patch) do
    NodeHelper.get_attr_value(patch, "patch")
  end

  def function(%Patch{} = patch) do
    NodeHelper.get_attr_value(patch, "function")
  end

  def method(%Patch{} = patch) do
    NodeHelper.get_attr_value(patch, "method")
  end

  def impl(%Patch{} = patch) do
    NodeHelper.get_attr_value(patch, "impl")
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Patch do
  import Rez.AST.NodeValidator

  def node_type(_patch), do: "patch"

  def js_ctor(_patch) do
    raise "@patch does not support a JS constructor!"
  end

  def default_attributes(_patch), do: %{}

  def pre_process(patch), do: patch

  def process(patch), do: patch

  def children(_patch), do: []

  def validators(_patch) do
    [
      attribute_present?("patch", attribute_has_type?(:string)),
      attribute_if_present?("function", attribute_has_type?(:string)),
      attribute_if_present?("method", attribute_has_type?(:string)),
      attribute_one_of_present?(["function", "method"], true),
      attribute_present?("impl", attribute_has_type?(:function)),
      attribute_must_not_be_present?("js_ctor")
    ]
  end
end
