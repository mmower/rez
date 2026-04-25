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

        Enum.each(entries, fn {module_path, version_ref, type} ->
          present = files_present(game_root, module_path, type)
          note = version_note(version_ref, latest_tag)
          IO.puts("  #{String.pad_trailing(module_path, 30)}  #{String.pad_trailing(version_ref, 12)}  [#{type}]  #{present}#{note}")
        end)

        IO.puts("")
        :ok

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  defp files_present(game_root, module_path, type) do
    rez_ok = type in ["pragma"] or File.exists?(Config.module_file_path(game_root, module_path))
    lua_ok = type in ["lib"] or File.exists?(Config.module_lua_file_path(game_root, module_path))

    cond do
      rez_ok and lua_ok -> "present"
      not rez_ok and not lua_ok -> "MISSING"
      not rez_ok -> "MISSING (.rez)"
      true -> "MISSING (.lua)"
    end
  end

  defp version_note("main", _latest), do: "  [unversioned — run 'rez cookbook update' to pin to latest]"
  defp version_note(_ref, nil), do: ""
  defp version_note(ref, latest) when ref == latest, do: ""
  defp version_note(_ref, latest), do: "  [UPDATE AVAILABLE: #{latest}]"
end
