defmodule Rez.Cookbook.Commands.Update do
  alias Rez.Cookbook.{Config, CookbookFile, Fetcher, Manifest}

  def run(game_root, []) do
    with {:ok, tag} <- fetch_tag(),
         {:ok, entries} <- Manifest.read(game_root),
         {:ok, index_type_map} <- fetch_index_type_map() do
      case entries do
        [] -> IO.puts("cookbook.deps is empty."); :ok
        _ ->
          updated_entries = Enum.map(entries, fn {module_path, _ref, _old_type} ->
            type = Map.get(index_type_map, module_path, "lib")
            {module_path, tag, type}
          end)
          fetch_and_report(game_root, updated_entries)
      end
    else
      {:error, reason} -> IO.puts("Error: #{reason}"); :error
    end
  end

  def run(game_root, module_paths) do
    with {:ok, tag} <- fetch_tag(),
         {:ok, entries} <- Manifest.read(game_root),
         {:ok, index_type_map} <- fetch_index_type_map() do
      targets =
        Enum.map(module_paths, fn module_path ->
          type =
            case List.keyfind(entries, module_path, 0) do
              {^module_path, _ref, existing_type} -> Map.get(index_type_map, module_path, existing_type)
              nil -> Map.get(index_type_map, module_path, "lib")
            end

          {module_path, tag, type}
        end)

      fetch_and_report(game_root, targets)
    else
      {:error, reason} -> IO.puts("Error: #{reason}"); :error
    end
  end

  defp fetch_tag do
    case Fetcher.fetch_latest_tag() do
      {:ok, tag} -> {:ok, tag}
      {:error, reason} -> {:error, "Could not determine latest cookbook version: #{reason}"}
    end
  end

  defp fetch_index_type_map do
    case Fetcher.fetch_index() do
      {:ok, body} when is_map(body) ->
        map =
          body
          |> Map.get("modules", [])
          |> Enum.reduce(%{}, fn module, acc ->
            name = module["name"]
            type = module["type"] || "lib"
            if name, do: Map.put(acc, name, type), else: acc
          end)

        {:ok, map}

      {:ok, _} ->
        {:ok, %{}}

      {:error, _} = err ->
        err
    end
  end

  defp fetch_and_report(game_root, entries) do
    results =
      Enum.map(entries, fn {module_path, version_ref, type} ->
        rez_result =
          if type in ["lib", "both"] do
            case Fetcher.fetch_module(module_path, version_ref) do
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
          if type in ["pragma", "both"] do
            case Fetcher.fetch_pragma(module_path, version_ref) do
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

        case {rez_result, lua_result} do
          {:ok, :ok} ->
            Manifest.put_entry(game_root, module_path, version_ref, type)
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
