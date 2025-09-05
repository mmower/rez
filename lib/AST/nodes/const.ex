defmodule Rez.AST.Const do
  @moduledoc """
  Defines a %Const{} AST node used for holding constant declarations
  created by the @const directive.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            name: nil,
            value: nil,
            value_type: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Const do
  def node_type(_const), do: "const"
  def js_ctor(_const), do: raise("@const does not support a JS constructor!")
  def html_processor(_const, _attr), do: raise("@const does not support HTML processing!")
  def js_initializer(_const), do: raise("@const does not support a JS initializer!")
  def process(const, _resources), do: const
end