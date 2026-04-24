defmodule Rez.Cookbook.Commands.Update do
  alias Rez.Cookbook.{Config, Fetcher, Manifest}

  def run(game_root, []) do
    with {:ok, tag} <- fetch_tag(),
         {:ok, entries} <- Manifest.read(game_root) do
      case entries do
        [] -> IO.puts("cookbook.deps is empty."); :ok
        _ -> fetch_and_report(game_root, entries, tag)
      end
    else
      {:error, reason} -> IO.puts("Error: #{reason}"); :error
    end
  end

  def run(game_root, module_paths) do
    with {:ok, tag} <- fetch_tag(),
         {:ok, entries} <- Manifest.read(game_root) do
      targets =
        Enum.map(module_paths, fn module_path ->
          case List.keyfind(entries, module_path, 0) do
            {^module_path, version_ref} -> {module_path, version_ref}
            nil -> {module_path, Config.default_ref()}
          end
        end)

      fetch_and_report(game_root, targets, tag)
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

  defp fetch_and_report(game_root, entries, tag) do
    results =
      Enum.map(entries, fn {module_path, _old_ref} ->
        case Fetcher.fetch_module(module_path, tag) do
          {:ok, content} ->
            dest = Config.module_file_path(game_root, module_path)
            File.mkdir_p!(Path.dirname(dest))
            File.write!(dest, content)
            Manifest.put_entry(game_root, module_path, tag)
            {:ok, module_path, tag}

          {:error, reason} ->
            {:error, module_path, tag, reason}
        end
      end)

    updated = for {:ok, path, ref} <- results, do: "#{path} (#{ref})"
    failed = for {:error, path, ref, reason} <- results, do: "#{path} (#{ref}) - #{reason}"

    unless Enum.empty?(updated), do: IO.puts("Updated:  #{Enum.join(updated, ", ")}")
    unless Enum.empty?(failed), do: IO.puts("Failed:   #{Enum.join(failed, ", ")}")

    if Enum.empty?(failed), do: :ok, else: :error
  end
end
