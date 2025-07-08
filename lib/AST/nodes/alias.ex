defmodule Rez.AST.Alias do
  @moduledoc """
  Specifies the Alias AST Node
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            name: nil,
            target: nil,
            mixins: [],
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Alias do
  def node_type(_alias), do: "alias"
  def js_ctor(_alias), do: raise("@alias does not support a JS constructor!")
  def html_processor(_alias, _attr), do: raise("@alias does not support HTML processors!")

  def js_initializer(_alias),
    do: raise("@alias does not support a JS initializer!")

  def process(alias, _resources), do: alias
end
