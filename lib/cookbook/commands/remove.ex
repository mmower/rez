defmodule Rez.Cookbook.Commands.Remove do
  alias Rez.Cookbook.{Config, Manifest}

  def run(_game_root, []) do
    IO.puts("Usage: rez cookbook remove <category/module> [...]")
    :error
  end

  def run(game_root, module_paths) do
    Enum.each(module_paths, fn module_path ->
      file = Config.module_file_path(game_root, module_path)

      if File.exists?(file) do
        File.rm!(file)
        IO.puts("Removed:  #{module_path}")
      else
        IO.puts("Not found: #{module_path} (file not present)")
      end

      Manifest.remove_entry(game_root, module_path)
    end)

    :ok
  end
end
