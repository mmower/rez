defmodule Rez.Cookbook.Commands.Docs do
  alias Rez.Cookbook.Config

  def run(_game_root, []) do
    IO.puts("Usage: rez cookbook docs <prefix>/<name>")
  end

  def run(game_root, [module_path | _]) do
    path = Config.module_md_file_path(game_root, module_path)

    if File.exists?(path) do
      open_file(path)
    else
      IO.puts("No docs available for #{module_path}")
    end
  end

  defp open_file(path) do
    cmd =
      cond do
        match?({_, 0}, System.cmd("which", ["xdg-open"], stderr_to_stdout: true)) -> "xdg-open"
        match?({_, 0}, System.cmd("which", ["open"], stderr_to_stdout: true)) -> "open"
        true -> nil
      end

    case cmd do
      nil ->
        IO.puts(File.read!(path))

      opener ->
        System.cmd(opener, [path])
        :ok
    end
  end
end
