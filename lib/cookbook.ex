defmodule Rez.Cookbook do
  @moduledoc """
  `Rez.Cookbook` implements the `rez cookbook` subcommand family for managing
  opt-in cookbook library modules from https://github.com/mmower/rez-cookbook.
  """

  alias Rez.Cookbook.Commands.{Init, List, Get, Update, Remove, Status, Docs}

  def run(args, game_root) do
    case args do
      ["init" | _] -> Init.run(game_root)
      ["list" | _] -> List.run(game_root)
      ["get" | modules] -> Get.run(game_root, modules)
      ["update" | modules] -> Update.run(game_root, modules)
      ["remove" | modules] -> Remove.run(game_root, modules)
      ["status" | _] -> Status.run(game_root)
      ["docs" | modules] -> Docs.run(game_root, modules)
      [] -> usage()
      [unknown | _] -> IO.puts("Error: unknown cookbook command '#{unknown}'")
    end
  end

  defp usage do
    IO.puts("""
    Usage: rez cookbook <command>

    Commands:
      init               Create cookbook.deps in the current game project
      list               Show available modules from the cookbook
      get [module...]    Fetch missing modules (or add and fetch named modules)
      update [module...] Re-fetch modules, overwriting local copies
      remove <module...> Remove modules from the project and manifest
      status             Show which manifest modules are present or missing
      docs <module>      Open documentation for a cookbook module
    """)
  end
end
