defmodule Rez.AST.List do

  @moduledoc """
  `Rez.AST.List` defines the `List` struct.

  A `List` represents a list of values. For example a list of
  options for character names.
  """

  defstruct [
    status: :ok,
    position: {nil, 0, 0},
    id: nil,
    attributes: %{}
  ]

end

defimpl Rez.AST.Node, for: Rez.AST.List do
  import Rez.AST.NodeValidator

  def node_type(_list), do: "list"

  def pre_process(list), do: list

  def process(list), do: list

  def children(_list), do: []

  def validators(_list) do
    [
      attribute_if_present?("tags",
        attribute_is_keyword_set?()),

      attribute_present?("values",
        attribute_has_type?(:list))
    ]
  end
end
