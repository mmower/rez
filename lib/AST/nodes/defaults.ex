defmodule Rez.AST.Defaults do
  @moduledoc """
  Defines a %Defaults{} AST node used for holding a particular element types
  default values.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            elem: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Defaults do
  def node_type(_defaults), do: "defaults"
  def js_ctor(_defaults), do: raise("@defaults does not support a JS constructor!")
  def html_processor(_defaults, _attr), do: raise("@defaults does not support HTML processing!")

  def js_initializer(_defaults),
    do: raise("@defaults does not support a JS initializer!")

  def process(defaults, _resources), do: defaults
end
