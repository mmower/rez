defmodule Rez.AST.Schema do
  @moduledoc """
  Specifies the Schema AST node.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            element: "",
            rules: [],
            metadata: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Schema do
  def node_type(_schema), do: "schema"
  def js_ctor(_schema), do: raise("@schema does not support a JS constructor!")
  def js_initializer(_schema), do: raise("@schema does not support a JS initializer!")
  def process(schema, _resources), do: schema
  def html_processor(_schema, _attr), do: raise("@schema does not support HTML processing!")
end
