defmodule Rez.AST.List do
  @moduledoc """
  `Rez.AST.List` defines the `List` struct.

  A `List` represents a list of values. For example a list of
  options for character names.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.List do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(list), to: NodeHelper
  defdelegate html_processor(list, attr), to: NodeHelper

  def node_type(_list), do: "list"

  def js_ctor(list) do
    NodeHelper.get_attr_value(list, "$js_ctor", "RezList")
  end

  def process(list, _) do
    list
  end
end
