defmodule Rez.AST.Game do
  @moduledoc """
  `Rez.AST.Game` contains the `Game` struct that is the root object for all
  game content.
  """
  alias __MODULE__

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: "game",
            attributes: %{},
            metadata: %{},
            validation: nil

end

defimpl Rez.AST.Node, for: Rez.AST.Game do
  alias Rez.Utils
  alias Rez.AST.NodeHelper
  alias Rez.AST.Game

  defdelegate js_initializer(game), to: NodeHelper

  def node_type(_game), do: "game"

  def js_ctor(game) do
    NodeHelper.get_attr_value(game, "$js_ctor", "RezGame")
  end

  def process(%Game{} = game, _), do: game

  def html_processor(game, "layout") do
    fn html ->
      custom_css_class = NodeHelper.get_attr_value(game, "css_class", "")
      css_classes = Utils.add_css_class("rez-game", custom_css_class)

      ~s|<div id="game" data-game=true class="#{css_classes}">#{html}</div>|
    end
  end

  def html_processor(game, attr), do: NodeHelper.html_processor(game, attr)
end
