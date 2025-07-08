defmodule Rez.AST.Faction do
  @moduledoc """
  `Rez.AST.Faction` contains the `Faction` struct that is used to represent
  in-game groups of `Actor`s.

  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Faction do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(faction), to: NodeHelper
  defdelegate html_processor(faction, attr), to: NodeHelper

  def node_type(_faction), do: "faction"

  def js_ctor(faction) do
    NodeHelper.get_attr_value(faction, "$js_ctor", "RezFaction")
  end

  def process(faction, _node_map), do: faction
end
