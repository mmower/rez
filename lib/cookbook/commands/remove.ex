defmodule Rez.Cookbook.Commands.Remove do
  alias Rez.Cookbook.{Config, CookbookFile, Manifest}

  def run(_game_root, []) do
    IO.puts("Usage: rez cookbook remove <category/module> [...]")
    :error
  end

  def run(game_root, module_paths) do
    Enum.each(module_paths, fn module_path ->
      dir = Config.module_dir_path(game_root, module_path)

      if File.dir?(dir) do
        File.rm_rf!(dir)
        IO.puts("Removed:  #{module_path}")
      else
        IO.puts("Not found: #{module_path} (directory not present)")
      end

      Manifest.remove_entry(game_root, module_path)
    end)

    CookbookFile.regenerate(game_root)
    :ok
  end
end
