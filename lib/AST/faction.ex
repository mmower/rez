defmodule Rez.AST.Faction do
  @moduledoc """
  `Rez.AST.Faction` contains the `Faction` struct that is used to represent
  in-game groups of `Actor`s.

  """
  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Faction do
  import Rez.AST.NodeValidator
  alias Rez.AST.NodeHelper

  def node_type(_faction), do: "faction"

  def js_ctor(effect) do
    NodeHelper.get_attr_value(effect, "js_ctor", "RezEffect")
  end

  def pre_process(faction), do: faction

  def process(faction), do: faction

  def children(_faction), do: []

  def validators(_faction) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
