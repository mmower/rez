defmodule Rez.AST.Style do
  @moduledoc """
  `Rez.AST.Style` defines the `Style` struct.

  A `Style` contains user-specified CSS that gets included into the browser
  page.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            styles: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Style do
  def node_type(_style), do: "style"

  def js_ctor(_style), do: raise("@style does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@style does not support a JS initializer!")

  def html_processor(_schema, _attr), do: raise("@style does not support HTML processing!")

  def process(style, _resources), do: style
end
