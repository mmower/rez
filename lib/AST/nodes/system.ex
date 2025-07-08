defmodule Rez.AST.System do
  @moduledoc """
  `Rez.AST.System` represents in-game systems for custom behaviours.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil

  @enabled_attr_key "enabled"

  def enabled?(%System{} = system) do
    NodeHelper.get_attr_value(system, @enabled_attr_key) == true
  end
end

defimpl Rez.AST.Node, for: Rez.AST.System do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(system), to: NodeHelper
  defdelegate html_processor(system, attr), to: NodeHelper

  def node_type(_system), do: "system"

  def js_ctor(system) do
    NodeHelper.get_attr_value(system, "$js_ctor", "RezSystem")
  end

  def process(system, _) do
    system
  end
end
