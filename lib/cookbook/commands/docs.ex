defmodule Rez.Cookbook.Commands.Docs do
  alias Rez.Cookbook.Config

  def run(_game_root, []) do
    IO.puts("Usage: rez cookbook docs <prefix>/<name>")
  end

  def run(game_root, [module_path | _]) do
    html_path = Config.module_docs_html_path(game_root, module_path)
    docs_dir = Config.module_docs_dir_path(game_root, module_path)
    module_name = Path.basename(module_path)
    md_path = Path.join(docs_dir, "#{module_name}.md")

    cond do
      File.exists?(html_path) -> open_file(html_path)
      File.exists?(md_path) -> open_file(md_path)
      true -> IO.puts("No docs available for #{module_path}")
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
