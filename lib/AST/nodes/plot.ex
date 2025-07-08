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

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Plot do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(plot), to: NodeHelper
  defdelegate html_processor(plot, attr), to: NodeHelper

  def node_type(_plot), do: "plot"

  def js_ctor(plot) do
    NodeHelper.get_attr_value(plot, "$js_ctor", "RezPlot")
  end

  def process(plot, _node_map) do
    plot
  end
end
