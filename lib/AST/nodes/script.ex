defmodule Rez.AST.Script do
  @moduledoc """
  `Rez.AST.Script` defines the `Script` module.

  A `Script` is user-generated Javascript that is added to the generated
  JS output.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            script: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Script do
  def node_type(_script), do: "script"

  def js_ctor(_script), do: raise("@script does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@script does not support a JS initializer!")

  def process(script, _resources), do: script

  def html_processor(_script, _attr), do: raise("@script does not support HTML processors!")
end
