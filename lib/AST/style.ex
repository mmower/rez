defmodule Rez.AST.Style do
  @moduledoc """
  `Rez.AST.Style` defines the `Style` struct.

  A `Style` contains user-specified CSS that gets included into the browser
  page.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Style do
  def node_type(_style), do: "style"

  def js_ctor(_style) do
    raise "@style does not support a JS constructor!"
  end

  def default_attributes(_style), do: %{}

  def pre_process(style), do: style

  def process(style), do: style

  def children(_style), do: []

  def validators(_script), do: []
end
