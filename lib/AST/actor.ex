defmodule Rez.AST.Actor do
  @moduledoc """
  `Rez.AST.Actor` contains the `Actor` struct and `Node` implementation.

  An `Actor` is used to represent e.g. the player, or NPCs in the game.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Actor do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(actor), to: NodeHelper

  def node_type(_actor), do: "actor"

  def js_ctor(actor) do
    NodeHelper.get_attr_value(actor, "$js_ctor", "RezActor")
  end

  def default_attributes(_actor),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0)
    }

  def pre_process(actor), do: actor

  def process(actor, _node_map) do
    actor
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_actor), do: []

  def validators(_actor) do
    [
      attribute_if_present?(
        "$init_after",
        attribute_has_type?(:list, attribute_coll_of?(:elem_ref))
      ),
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "on_accept_item",
        attribute_has_type?(
          :function,
          validate_expects_params?(["actor", "event"])
        )
      ),
      attribute_if_present?(
        "container_id",
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
