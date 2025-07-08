defmodule Rez.AST.Derive do
  @moduledoc """
  Specifies the Derive AST node.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            tag: nil,
            parent: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Derive do
  def node_type(_derive), do: "derive"
  def js_ctor(_derive), do: raise("@derive does not support a JS constructor!")
  def html_processor(_derive, _attr), do: raise("@derive does not support HTML processing!")

  def js_initializer(_derive),
    do: raise("@derive does not support a JS initializer!")

  def process(derive, _resources), do: derive
end
