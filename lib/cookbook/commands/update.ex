defmodule Rez.Cookbook.Commands.Update do
  alias Rez.Cookbook.{Config, CookbookFile, Fetcher, Manifest}

  def run(game_root, []) do
    with {:ok, module_index} <- Fetcher.fetch_module_index(),
         {:ok, entries} <- Manifest.read(game_root) do
      case entries do
        [] ->
          IO.puts("cookbook.toml is empty.")
          :ok

        _ ->
          updated_entries = Enum.map(entries, fn {module_path, _ref, _old_types} ->
            info = Map.get(module_index, module_path, %{})
            types = Manifest.index_type_to_list(info["type"] || "lib")
            version = info["version"] || Config.default_ref()
            {module_path, version, types}
          end)

          fetch_and_report(game_root, updated_entries)
      end
    else
      {:error, reason} -> IO.puts("Error: #{reason}"); :error
    end
  end

  def run(game_root, module_paths) do
    with {:ok, module_index} <- Fetcher.fetch_module_index(),
         {:ok, entries} <- Manifest.read(game_root) do
      targets =
        Enum.map(module_paths, fn module_path ->
          info = Map.get(module_index, module_path)

          {types, version} =
            if info do
              {Manifest.index_type_to_list(info["type"] || "lib"), info["version"] || Config.default_ref()}
            else
              case List.keyfind(entries, module_path, 0) do
                {^module_path, existing_ref, existing_types} -> {existing_types, existing_ref}
                nil -> {["lib"], Config.default_ref()}
              end
            end

          {module_path, version, types}
        end)

      fetch_and_report(game_root, targets)
    else
      {:error, reason} -> IO.puts("Error: #{reason}"); :error
    end
  end

  defp fetch_and_report(game_root, entries) do
    fetch_ref = Config.default_ref()

    results =
      Enum.map(entries, fn {module_path, version_ref, types} ->
        rez_result =
          if "lib" in types do
            case Fetcher.fetch_module(module_path, fetch_ref) do
              {:ok, content} ->
                dest = Config.module_file_path(game_root, module_path)
                File.mkdir_p!(Path.dirname(dest))
                File.write!(dest, content)
                :ok

              {:error, reason} ->
                {:error, reason}
            end
          else
            :ok
          end

        lua_result =
          if "pragma" in types do
            case Fetcher.fetch_pragma(module_path, fetch_ref) do
              {:ok, content} ->
                dest = Config.module_lua_file_path(game_root, module_path)
                File.mkdir_p!(Path.dirname(dest))
                File.write!(dest, content)
                :ok

              :not_found ->
                {:error, "pragma .lua not found in cookbook repo"}

              {:error, reason} ->
                {:error, reason}
            end
          else
            :ok
          end

        case Fetcher.fetch_docs(module_path, fetch_ref) do
          {:ok, content} ->
            dest = Config.module_md_file_path(game_root, module_path)
            File.mkdir_p!(Path.dirname(dest))
            File.write!(dest, content)
          _ -> :ok
        end

        case {rez_result, lua_result} do
          {:ok, :ok} ->
            Manifest.put_entry(game_root, module_path, version_ref, types)
            {:ok, module_path, version_ref}

          {{:error, reason}, _} ->
            {:error, module_path, version_ref, reason}

          {_, {:error, reason}} ->
            {:error, module_path, version_ref, reason}
        end
      end)

    updated = for {:ok, path, ref} <- results, do: "#{path} (#{ref})"
    failed = for {:error, path, ref, reason} <- results, do: "#{path} (#{ref}) - #{reason}"

    unless Enum.empty?(updated), do: IO.puts("Updated:  #{Enum.join(updated, ", ")}")
    unless Enum.empty?(failed), do: IO.puts("Failed:   #{Enum.join(failed, ", ")}")

    CookbookFile.regenerate(game_root)
    if Enum.empty?(failed), do: :ok, else: :error
  end
end
