defmodule Rez.AST.Filter do
  @moduledoc """
  `Rez.AST.Filter` defines the %Filter struct that represents a @filter in-game
  element. A Filter contains a function defining an template expression filter.
  """

  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Filter do
  def node_type(_filter), do: "filter"

  def js_ctor(_filter) do
    raise "@filter does not support JS constructor!"
  end

  def js_initializer(_obj), do: raise("@filter does not support JS initializer!")

  def process(filter, _node_map), do: filter

  def html_processor(_filter, _attr), do: raise("@filter does not support HTML processors!")
end
