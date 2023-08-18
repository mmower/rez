defmodule Rez.AST.Filter do
  @moduledoc """
  `Rez.AST.Filter` defines the %Filter struct that represents a @filter in-game
  element. A Filter contains a function defining an template expression filter.
  """

  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Filter do
  import Rez.AST.NodeValidator

  def node_type(_filter), do: "filter"

  def js_ctor(_filter) do
    raise "@filter does not support JS constructor!"
  end

  def js_initializer(_obj), do: raise("@filter does not support JS initializer!")

  def default_attributes(_filter), do: %{}

  def pre_process(filter), do: filter

  def process(filter), do: filter

  def children(_filter), do: []

  def validators(_filter) do
    [
      attribute_present?(
        "name",
        attribute_has_type?(:string)
      ),
      attribute_present?(
        "impl",
        attribute_has_type?(:function)
      ),
      attribute_must_not_be_present?("js_ctor")
    ]
  end
end
