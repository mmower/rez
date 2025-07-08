defmodule Rez.AST.KeyBinding do
  @moduledoc """
  Specifies the KeyBinding AST node.
  """
  alias Rez.AST.KeyBinding

  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            modifiers: nil,
            key: nil,
            event: nil,
            metadata: %{},
            validation: nil

  def key_test_fn(%KeyBinding{modifiers: modifiers, key: key}) do
    key_p = ~s|event.key === "#{key}"|

    modifier_p =
      Enum.reduce(modifiers, "", fn {modifier, truth}, test ->
        if truth do
          test <> "event.#{modifier} && "
        else
          test <> "!event.#{modifier} && "
        end
      end)

    "(event) => #{modifier_p}#{key_p}"
  end
end

defimpl Rez.AST.Node, for: Rez.AST.KeyBinding do
  def node_type(_keybinding), do: "keybinding"
  def js_ctor(_keybinding), do: raise("@keybinding does not support a JS constructor!")

  def html_processor(_template, _attr),
    do: raise("@keybinding does not support HTML processing!")

  def js_initializer(_keybinding),
    do: raise("@keybinding does not support a JS initializer!")

  def process(keybinding, _resources), do: keybinding
end
