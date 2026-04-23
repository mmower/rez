defmodule Rez.Cookbook.Commands.Status do
  alias Rez.Cookbook.{Config, Manifest}

  def run(game_root) do
    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.deps is empty.")
        :ok

      {:ok, entries} ->
        IO.puts("\nCookbook status:\n")

        Enum.each(entries, fn {module_path, version_ref} ->
          file = Config.module_file_path(game_root, module_path)
          state = if File.exists?(file), do: "present", else: "MISSING"
          IO.puts("  #{String.pad_trailing(module_path, 30)}  #{String.pad_trailing(version_ref, 12)}  #{state}")
        end)

        IO.puts("")
        :ok

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end
end
