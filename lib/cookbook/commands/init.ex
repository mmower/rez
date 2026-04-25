defmodule Rez.Cookbook.Commands.Init do
  alias Rez.Cookbook.Config

  def run(game_root) do
    path = Config.manifest_path(game_root)

    if File.exists?(path) do
      IO.puts("cookbook.toml already exists at #{path}")
      :ok
    else
      File.write!(path, """
      # Rez Cookbook Dependencies
      # Run 'rez cookbook list' to see available modules.
      # Run 'rez cookbook get <category/module>' to add a module.
      """)

      cookbook_lib = Config.cookbook_lib_path(game_root)
      File.mkdir_p!(cookbook_lib)

      IO.puts("Created cookbook.toml")
      :ok
    end
  end
end
