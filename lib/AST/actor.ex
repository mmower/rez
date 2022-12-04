defmodule Rez.AST.Actor do
  @moduledoc """
  `Rez.AST.Actor` contains the `Actor` struct and `Node` implementation.

  An `Actor` is used to represent e.g. the player, or NPCs in the game.
  """

  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Actor do
  import Rez.AST.NodeValidator

  def node_type(_actor), do: "actor"

  def pre_process(actor), do: actor

  def process(actor), do: actor

  def children(_actor), do: []

  def validators(_actor) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "on_accept_item",
        attribute_has_type?(
          :function,
          validate_expects_params?(["actor", "event"])
        )
      ),
      attribute_if_present?(
        "initial_location",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("location")
        )
      ),
      attribute_if_present?(
        "container",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("inventory")
        )
      ),
      attribute_if_present?(
        "on_enter",
        attribute_has_type?(
          :function,
          validate_expects_params?(["actor", "event"])
        )
      ),
      attribute_if_present?(
        "on_leave",
        attribute_has_type?(
          :function,
          validate_expects_params?(["actor", "event"])
        )
      ),
      attribute_if_present?(
        "on_turn",
        attribute_has_type?(
          :function,
          validate_expects_params?(["actor", "event"])
        )
      ),
      attribute_if_present?(
        "behaviours",
        attribute_has_type?(
          :btree,
          validate_is_btree?()
        )
      )
    ]
  end
end
