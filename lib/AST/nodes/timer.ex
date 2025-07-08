defmodule Rez.AST.Timer do
  @moduledoc """
  `Rez.AST.Timer` contains the `Timer` struct and its `Node` implementation.

  A `Timer` is used to represent an event generator that is triggered by a
  real-time delay (e.g. in 5s send this event).
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Timer do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(timer), to: NodeHelper
  defdelegate html_processor(timer, attr), to: NodeHelper

  def node_type(_timer), do: "timer"

  def js_ctor(timer) do
    NodeHelper.get_attr_value(timer, "$js_ctor", "RezTimer")
  end

  def process(timer, _) do
    timer
  end
end
