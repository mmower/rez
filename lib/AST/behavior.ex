defmodule Rez.AST.Behaviour do
  @moduledoc """
  `Rez.AST.Actor` contains the `Actor` struct and `Node` implementation.

  An `Actor` is used to represent e.g. the player, or NPCs in the game.
  """

  defstruct [
    status: :ok,
    position: {nil, 0, 0},
    id: nil,
    attributes: %{},
  ]
end

defimpl Rez.AST.Node, for: Rez.AST.Behaviour do
  import Rez.AST.NodeValidator

  def node_type(_behaviour), do: "behaviour"

  def pre_process(behavior), do: behavior

  def process(behaviour), do: behaviour

  def children(_behaviour), do: []

  def validators(_behaviour) do
    [
      attribute_present?("options",
        attribute_has_type?(:list,
          attribute_coll_of?(:keyword))),

      attribute_if_present?("check_children",
        attribute_has_type?(:function)),

      attribute_present?("execute",
        attribute_has_type?(:function,
          validate_expects_params?(["behaviour", "wmem"])))
    ]
  end
end
