defmodule Rez.AST.Mixin do
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Mixin do
  import Rez.AST.NodeValidator

  def node_type(_mixin), do: "mixin"

  def js_ctor(_mixin), do: raise("@mixin does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@mixin does not support a JS initializer!")

  def default_attributes(_mixin), do: %{}

  def pre_process(mixin), do: mixin

  def process(mixin, _resources), do: mixin

  def children(_mixin), do: []

  def validators(_mixin) do
    [
      attributes_are_functions?()
    ]
  end
end
