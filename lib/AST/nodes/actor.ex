defmodule Rez.AST.Actor do
  @moduledoc """
  `Rez.AST.Actor` contains the `Actor` struct and `Node` implementation.

  An `Actor` is used to represent e.g. the player, or NPCs in the game.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Actor do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(actor), to: NodeHelper
  defdelegate html_processor(actor, attr), to: NodeHelper

  def node_type(_actor), do: "actor"

  def js_ctor(actor) do
    NodeHelper.get_attr_value(actor, "$js_ctor", "RezActor")
  end

  def process(actor, _), do: actor
end
