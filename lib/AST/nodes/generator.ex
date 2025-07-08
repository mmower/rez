defmodule Rez.AST.Generator do
  @moduledoc """
  `Rez.AST.Generator` contains the `Generator` struct that is used to represent
  run-time procedural generators.
  """
  defstruct status: :ok,
            # technically not, but it resovles to a RezList of the same id
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Generator do
  def html_processor(_generator, _attr), do: raise("@generator does not support HTML processing!")

  def node_type(_generator), do: "generator"

  def js_ctor(_generator), do: raise("@generator does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@generator does not support a JS initializer!")

  def process(generator, _node_map) do
    generator
  end
end
