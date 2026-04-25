defmodule Rez.Cookbook.Commands.Get do
  alias Rez.Cookbook.{Config, CookbookFile, Fetcher, Manifest}

  def run(game_root, []) do
    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.deps is empty. Add modules with 'rez cookbook get <category/module>'.")
        :ok

      {:ok, entries} ->
        missing =
          Enum.reject(entries, fn {module_path, _ref, type} ->
            rez_present = type in ["pragma"] or File.exists?(Config.module_file_path(game_root, module_path))
            lua_present = type in ["lib"] or File.exists?(Config.module_lua_file_path(game_root, module_path))
            rez_present and lua_present
          end)

        if Enum.empty?(missing) do
          IO.puts("All cookbook modules already present.")
          :ok
        else
          fetch_and_report(game_root, missing)
        end

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  def run(game_root, module_paths) do
    with {:ok, tag} <- Fetcher.fetch_latest_tag(),
         {:ok, existing_entries} <- Manifest.read(game_root),
         {:ok, index_modules} <- fetch_index_type_map() do
      default_ref = Config.default_ref()

      entries =
        Enum.map(module_paths, fn module_path ->
          type = Map.get(index_modules, module_path, "lib")

          ref =
            case List.keyfind(existing_entries, module_path, 0) do
              {^module_path, existing_ref, _type} when existing_ref != default_ref -> existing_ref
              _ -> tag
            end

          {module_path, ref, type}
        end)

      result = fetch_and_report(game_root, entries)

      Enum.each(entries, fn {module_path, version_ref, type} ->
        Manifest.put_entry(game_root, module_path, version_ref, type)
      end)

      CookbookFile.regenerate(game_root)
      result
    else
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        :error
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
          {:ok, :ok} -> {:ok, module_path, version_ref}
          {{:error, reason}, _} -> {:error, module_path, version_ref, reason}
          {_, {:error, reason}} -> {:error, module_path, version_ref, reason}
        end
      end)

    fetched = for {:ok, path, ref} <- results, do: "#{path} (#{ref})"
    failed = for {:error, path, ref, reason} <- results, do: "#{path} (#{ref}) - #{reason}"

    unless Enum.empty?(fetched), do: IO.puts("Fetched:  #{Enum.join(fetched, ", ")}")
    unless Enum.empty?(failed), do: IO.puts("Failed:   #{Enum.join(failed, ", ")}")

    if Enum.empty?(failed), do: :ok, else: :error
  end
end
