defmodule Rez.AST.Component do
  @moduledoc """
  Implements the Component AST node.

  A Component represents a

  @component name (bindings, assigns, content) => {
  }
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            name: nil,
            impl_fn: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Component do
  def node_type(_component), do: "component"
  def js_ctor(_component), do: raise("@component does not support a JS constructor!")
  def html_processor(_component, _attr), do: raise("@component does not support HTML processing!")

  def js_initializer(_component),
    do: raise("@component does not support a JS initializer!")

  def process(component, _resources), do: component
end
