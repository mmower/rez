defmodule Rez.AST.BehaviourTemplate do
  @moduledoc """
  Specifies the BehaviourTemplate AST node.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            template: nil,
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.BehaviourTemplate do
  def node_type(_template), do: "behaviour_template"
  def js_ctor(_template), do: raise("@behaviour_template does not support a JS constructor!")

  def html_processor(_template, _attr),
    do: raise("@behaviour_template does not support HTML processing!")

  def js_initializer(_template),
    do: raise("@behaviour_template does not support a JS initializer!")

  def process(template, _resources), do: template
end
