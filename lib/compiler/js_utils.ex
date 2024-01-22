defmodule Rez.Compiler.JsUtils do
  def key_test_fn({:keybinding, {:modifiers, modifiers}, key_name, _}) do
    key_p = ~s|event.key === "#{key_name}"|
    modifier_p = Enum.reduce(modifiers, "", fn {modifier, truth}, test ->
      if truth do
        test <> "event.#{modifier} && "
      else
        test <> "!event.#{modifier} && "
      end
    end)
    "(event) => #{modifier_p}#{key_p}"
  end
end
