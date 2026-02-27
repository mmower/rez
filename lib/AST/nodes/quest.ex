defmodule Rez.AST.Quest do
  @moduledoc """
  `Rez.AST.Quest` defines the `Quest` struct.

  A `Quest` represents a narrative task that the player may be able or
  expected to perform. Quests usually have a quest giver to whom the
  quest is later "turned in" for a reward.

  Quests differ from plot clocks.

  Additionally it is easier to intertwine `Plot`s by having the `Stage`s of one
  `Plot`, depend, upon the current `Stage` of another `Plot`.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Quest do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(quest), to: NodeHelper
  defdelegate html_processor(quest, attr), to: NodeHelper

  def node_type(_quest), do: "quest"

  def js_ctor(quest) do
    NodeHelper.get_attr_value(quest, "$js_ctor", "RezQuest")
  end

  def process(quest, _node_map) do
    quest
  end
end
