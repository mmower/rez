defmodule Rez.AST.Mixin do
  @moduledoc """
  Specifies the Mixin AST node.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Mixin do
  def node_type(_mixin), do: "mixin"

  def js_ctor(_mixin), do: raise("@mixin does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@mixin does not support a JS initializer!")

  def process(mixin, _resources), do: mixin

  def html_processor(_mixin, _attr), do: raise("@mixin does not support HTML processors!")
end
