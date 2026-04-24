defmodule Rez.Cookbook.Commands.Status do
  alias Rez.Cookbook.{Config, Fetcher, Manifest}

  def run(game_root) do
    latest_tag = case Fetcher.fetch_latest_tag() do
      {:ok, tag} -> tag
      {:error, _} -> nil
    end

    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.deps is empty.")
        :ok

      {:ok, entries} ->
        header = if latest_tag, do: "Cookbook status (latest: #{latest_tag}):", else: "Cookbook status (latest: unknown):"
        IO.puts("\n#{header}\n")

        Enum.each(entries, fn {module_path, version_ref} ->
          file = Config.module_file_path(game_root, module_path)
          present = if File.exists?(file), do: "present", else: "MISSING"
          note = version_note(version_ref, latest_tag)
          IO.puts("  #{String.pad_trailing(module_path, 30)}  #{String.pad_trailing(version_ref, 12)}  #{present}#{note}")
        end)

        IO.puts("")
        :ok

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  defp version_note("main", _latest), do: "  [unversioned — run 'rez cookbook update' to pin to latest]"
  defp version_note(_ref, nil), do: ""
  defp version_note(ref, latest) when ref == latest, do: ""
  defp version_note(_ref, latest), do: "  [UPDATE AVAILABLE: #{latest}]"
end
