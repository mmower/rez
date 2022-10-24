defmodule Rez.AST.Plot do
  @moduledoc """
  `Rez.AST.Plot` defines the `Plot` struct.

  A `Plot` represents an element of structured narrative within a game. Every
  `Plot` has `Stage`s that represent the players current narrative progress in
  that `Plot`.

  Each `Stage` has requirements that must be met before the player can advance
  the plot to that `Stage`.

  The game can query a `Plot` to see how far advanced it is and therefore
  present the appropriate options (e.g. different scenes, cards, dialog,
  or actions) available to the player.

  Additionally it is easier to intertwine `Plot`s by having the `Stage`s of one
  `Plot`, depend, upon the current `Stage` of another `Plot`.
  """

  defstruct [
    status: :ok,
    position: {nil, 0, 0},
    id: nil,
    attributes: %{}
  ]

end

defimpl Rez.AST.Node, for: Rez.AST.Plot do
  import Rez.AST.NodeValidator

  def node_type(_plot), do: "plot"

  def pre_process(plot), do: plot

  def process(plot), do: plot

  def children(_plot), do: []

  def validators(_plot) do
    [
      attribute_if_present?("tags",
        attribute_is_keyword_set?()),

      attribute_present?("ticks",
        attribute_has_type?(:number)),

      attribute_if_present?("on_begin",
        attribute_has_type?(:function)),

      attribute_if_present?("on_tick",
        attribute_has_type?(:function))
    ]
  end
end
