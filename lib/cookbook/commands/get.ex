defmodule Rez.Cookbook.Commands.Get do
  alias Rez.Cookbook.{Config, CookbookFile, Fetcher, Manifest}

  def run(game_root, []) do
    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.toml is empty. Add modules with 'rez cookbook get <category/module>'.")
        :ok

      {:ok, entries} ->
        missing =
          Enum.reject(entries, fn {module_path, _ref, _types} ->
            File.dir?(Config.module_dir_path(game_root, module_path))
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
    with {:ok, module_index} <- Fetcher.fetch_module_index(),
         {:ok, existing_entries} <- Manifest.read(game_root) do
      default_ref = Config.default_ref()

      entries =
        Enum.map(module_paths, fn module_path ->
          info = Map.get(module_index, module_path, %{})

          ref =
            case List.keyfind(existing_entries, module_path, 0) do
              {^module_path, existing_ref, _type} when existing_ref != default_ref -> existing_ref
              _ -> info["version"] || default_ref
            end

          {module_path, ref, []}
        end)

      fetch_and_report(game_root, entries)
    else
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        :error
    end
  end

  defp fetch_and_report(game_root, entries) do
    fetch_ref = Config.default_ref()

    results =
      Enum.map(entries, fn {module_path, version_ref, _types} ->
        case Fetcher.fetch_manifest(module_path, fetch_ref) do
          {:ok, manifest} ->
            dir = Config.module_dir_path(game_root, module_path)
            File.mkdir_p!(dir)

            lib_result = fetch_module_files(game_root, module_path, manifest["lib"] || [], fetch_ref)
            pragma_result = fetch_module_files(game_root, module_path, manifest["pragma"] || [], fetch_ref)
            fetch_and_render_docs(game_root, module_path, manifest["docs"] || [], fetch_ref)

            types = derive_types(manifest)
            Manifest.put_entry(game_root, module_path, version_ref, types)

            case {lib_result, pragma_result} do
              {:ok, :ok} -> {:ok, module_path, version_ref}
              {{:error, reason}, _} -> {:error, module_path, version_ref, reason}
              {_, {:error, reason}} -> {:error, module_path, version_ref, reason}
            end

          :not_found ->
            {:error, module_path, version_ref, "manifest.json not found in cookbook repo"}

          {:error, reason} ->
            {:error, module_path, version_ref, reason}
        end
      end)

    fetched = for {:ok, path, ref} <- results, do: "#{path} (#{ref})"
    failed = for {:error, path, ref, reason} <- results, do: "#{path} (#{ref}) - #{reason}"

    unless Enum.empty?(fetched), do: IO.puts("Fetched:  #{Enum.join(fetched, ", ")}")
    unless Enum.empty?(failed), do: IO.puts("Failed:   #{Enum.join(failed, ", ")}")

    CookbookFile.regenerate(game_root)
    if Enum.empty?(failed), do: :ok, else: :error
  end

  defp fetch_module_files(_game_root, _module_path, [], _version_ref), do: :ok

  defp fetch_module_files(game_root, module_path, filenames, version_ref) do
    Enum.reduce_while(filenames, :ok, fn filename, _ ->
      case Fetcher.fetch_module_file(module_path, filename, version_ref) do
        {:ok, content} ->
          dest = Config.module_file_path(game_root, module_path, filename)
          File.write!(dest, content)
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_and_render_docs(_game_root, _module_path, [], _version_ref), do: :ok

  defp fetch_and_render_docs(game_root, module_path, doc_files, version_ref) do
    docs_dir = Config.module_docs_dir_path(game_root, module_path)
    File.mkdir_p!(docs_dir)

    md_content =
      Enum.reduce(doc_files, nil, fn filename, md_acc ->
        case Fetcher.fetch_docs_file(module_path, filename, version_ref) do
          {:ok, content} ->
            File.write!(Path.join(docs_dir, filename), content)
            if is_nil(md_acc) and String.ends_with?(filename, ".md"), do: content, else: md_acc

          _ ->
            md_acc
        end
      end)

    if md_content do
      html = Earmark.as_html!(md_content, footnotes: true) |> wrap_html()
      File.write!(Config.module_docs_html_path(game_root, module_path), html)
    end

    :ok
  end

  defp wrap_html(body) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #333; }
        pre { background: #f5f5f5; padding: 1rem; border-radius: 4px; overflow-x: auto; }
        code { background: #f5f5f5; padding: 0.2em 0.4em; border-radius: 3px; font-size: 0.9em; }
        pre code { background: none; padding: 0; }
        img { max-width: 100%; }
        h1, h2, h3 { color: #222; }
      </style>
    </head>
    <body>
    #{body}
    </body>
    </html>
    """
  end

  defp derive_types(manifest) do
    [
      if(Map.has_key?(manifest, "lib"), do: "lib", else: nil),
      if(Map.has_key?(manifest, "pragma"), do: "pragma", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> then(fn
      [] -> ["lib"]
      types -> types
    end)
  end
end
