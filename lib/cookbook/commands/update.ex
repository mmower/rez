defmodule Rez.Cookbook.Commands.Update do
  alias Rez.Cookbook.{Config, Fetcher, Manifest}

  def run(game_root, []) do
    case Manifest.read(game_root) do
      {:ok, []} ->
        IO.puts("cookbook.deps is empty.")
        :ok

      {:ok, entries} ->
        fetch_and_report(game_root, entries)

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  def run(game_root, module_paths) do
    case Manifest.read(game_root) do
      {:ok, entries} ->
        targets =
          Enum.map(module_paths, fn module_path ->
            case List.keyfind(entries, module_path, 0) do
              {^module_path, version_ref} -> {module_path, version_ref}
              nil -> {module_path, Config.default_ref()}
            end
          end)

        fetch_and_report(game_root, targets)

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  defp fetch_and_report(game_root, entries) do
    results =
      Enum.map(entries, fn {module_path, version_ref} ->
        case Fetcher.fetch_module(module_path, version_ref) do
          {:ok, content} ->
            dest = Config.module_file_path(game_root, module_path)
            File.mkdir_p!(Path.dirname(dest))
            File.write!(dest, content)
            {:ok, module_path, version_ref}

          {:error, reason} ->
            {:error, module_path, version_ref, reason}
        end
      end)

    updated = for {:ok, path, ref} <- results, do: "#{path} (#{ref})"
    failed = for {:error, path, ref, reason} <- results, do: "#{path} (#{ref}) - #{reason}"

    unless Enum.empty?(updated), do: IO.puts("Updated:  #{Enum.join(updated, ", ")}")
    unless Enum.empty?(failed), do: IO.puts("Failed:   #{Enum.join(failed, ", ")}")

    if Enum.empty?(failed), do: :ok, else: :error
  end
end
