defmodule Rez.AST.Script do
  @moduledoc """
  `Rez.AST.Script` defines the `Script` module.

  A `Script` is user-generated Javascript that is added to the generated
  JS output.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Script do
  def node_type(_script), do: "script"

  def js_ctor(_script), do: raise("@script does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@script does not support a JS initializer!")

  def default_attributes(_script), do: %{}

  def pre_process(script), do: script

  def process(script), do: script

  def children(_script), do: []

  def validators(_script), do: []
end
