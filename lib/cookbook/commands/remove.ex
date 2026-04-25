defmodule Rez.Cookbook.Commands.Remove do
  alias Rez.Cookbook.{Config, CookbookFile, Manifest}

  def run(_game_root, []) do
    IO.puts("Usage: rez cookbook remove <category/module> [...]")
    :error
  end

  def run(game_root, module_paths) do
    Enum.each(module_paths, fn module_path ->
      rez_file = Config.module_file_path(game_root, module_path)
      lua_file = Config.module_lua_file_path(game_root, module_path)

      if File.exists?(rez_file) or File.exists?(lua_file) do
        if File.exists?(rez_file), do: File.rm!(rez_file)
        if File.exists?(lua_file), do: File.rm!(lua_file)
        IO.puts("Removed:  #{module_path}")
      else
        IO.puts("Not found: #{module_path} (file not present)")
      end

      Manifest.remove_entry(game_root, module_path)
    end)

    CookbookFile.regenerate(game_root)
    :ok
  end
end
