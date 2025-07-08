defmodule Rez.AST.Patch do
  @moduledoc """
  `Rez.AST.Patch` contains the `Patch` struct and its `Node` implementation.

  A `Patch` is used to represent a new method added to a class at runtime.
  """

  alias __MODULE__

  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            attributes: %{},
            metadata: %{},
            validation: nil

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
  def node_type(_patch), do: "patch"

  def js_ctor(_patch), do: raise("@patch does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@patch does not support a JS initializer!")

  def process(patch, _resources), do: patch

  def html_processor(_patch, _attr), do: raise("@patch does not support templates!")
end
