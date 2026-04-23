defmodule Rez.Cookbook.Manifest do
  @moduledoc """
  `Rez.Cookbook.Manifest` handles reading and writing the `cookbook.deps` manifest file.

  Each non-comment line is: `<category/module> [<version_ref>]`
  """

  alias Rez.Cookbook.Config

  @doc """
  Reads the manifest and returns `{:ok, [{module_path, version_ref}]}` or `{:error, reason}`.
  """
  def read(game_root) do
    path = Config.manifest_path(game_root)

    case File.read(path) do
      {:ok, content} -> {:ok, parse(content)}
      {:error, :enoent} -> {:error, "No cookbook.deps found. Run 'rez cookbook init' first."}
      {:error, reason} -> {:error, "Could not read cookbook.deps: #{reason}"}
    end
  end

  @doc """
  Adds or replaces an entry for `module_path` in the manifest.
  """
  def put_entry(game_root, module_path, version_ref) do
    path = Config.manifest_path(game_root)
    content = if File.exists?(path), do: File.read!(path), else: ""
    lines = String.split(content, "\n")

    updated =
      if Enum.any?(lines, &entry_matches?(&1, module_path)) do
        Enum.map(lines, fn line ->
          if entry_matches?(line, module_path), do: format_entry(module_path, version_ref), else: line
        end)
      else
        lines ++ [format_entry(module_path, version_ref)]
      end

    File.write!(path, Enum.join(updated, "\n"))
  end

  @doc """
  Removes the entry for `module_path` from the manifest.
  """
  def remove_entry(game_root, module_path) do
    path = Config.manifest_path(game_root)

    case File.read(path) do
      {:ok, content} ->
        updated =
          content
          |> String.split("\n")
          |> Enum.reject(&entry_matches?(&1, module_path))
          |> Enum.join("\n")

        File.write!(path, updated)

      {:error, reason} ->
        {:error, "Could not update cookbook.deps: #{reason}"}
    end
  end

  defp parse(content) do
    content
    |> String.split("\n")
    |> Enum.reject(&comment_or_blank?/1)
    |> Enum.map(&parse_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_line(line) do
    case String.split(String.trim(line), ~r/\s+/, parts: 2) do
      [name, version_ref] -> {name, version_ref}
      [name] when name != "" -> {name, Rez.Cookbook.Config.default_ref()}
      _ -> nil
    end
  end

  defp comment_or_blank?(line) do
    trimmed = String.trim(line)
    trimmed == "" or String.starts_with?(trimmed, "#")
  end

  defp entry_matches?(line, module_path) do
    trimmed = String.trim(line)
    not comment_or_blank?(line) and
      case String.split(trimmed, ~r/\s+/, parts: 2) do
        [^module_path | _] -> true
        _ -> false
      end
  end

  defp format_entry(module_path, version_ref) do
    if version_ref == Config.default_ref() do
      module_path
    else
      "#{module_path} #{version_ref}"
    end
  end
end
