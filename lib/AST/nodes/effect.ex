defmodule Rez.AST.Effect do
  @moduledoc """
  `Rez.AST.Effect` contains the `Effect` struct that represents in-game
  effects that can be applied to play, for example by possessing or using
  an item.

  Effects work principally through their `on_add` and `on_remove` attributes.
  When an effect is applied `on_add` will be called, conversely `on_remove`
  is called when the effect is removed.

  The optional `on_turn` function is intended to be called by the game engine
  whenever a turn is indicated and is an opportunity for the effect to be
  modified over time.

  Note: if we had a stat model baked into Rez it might be possible to specify
  effects declaratively.
  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Effect do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(effect), to: NodeHelper
  defdelegate html_processor(effect, attr), to: NodeHelper

  def node_type(_effect), do: "effect"

  def js_ctor(effect) do
    NodeHelper.get_attr_value(effect, "$js_ctor", "RezEffect")
  end

  def process(effect, _node_map) do
    effect
  end
end
