defmodule Rez.Cookbook.Commands.Status do
  alias Rez.Cookbook.{Config, Fetcher, Manifest}

  def run(game_root) do
    module_index = case Fetcher.fetch_module_index() do
      {:ok, idx} -> idx
      {:error, _} -> %{}
    end

    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.toml is empty.")
        :ok

      {:ok, entries} ->
        IO.puts("\nCookbook status:\n")

        Enum.each(entries, fn {module_path, version_ref, types} ->
          present = files_present(game_root, module_path, types)
          latest = get_in(module_index, [module_path, "version"])
          note = version_note(version_ref, latest)
          IO.puts("  #{String.pad_trailing(module_path, 30)}  #{String.pad_trailing(version_ref, 12)}  [#{Enum.join(types, ",")}]  #{present}#{note}")
        end)

        IO.puts("")
        :ok

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  defp files_present(game_root, module_path, types) do
    rez_ok = not ("lib" in types) or File.exists?(Config.module_file_path(game_root, module_path))
    lua_ok = not ("pragma" in types) or File.exists?(Config.module_lua_file_path(game_root, module_path))

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
