defmodule Rez.Cookbook.Manifest do
  @moduledoc """
  `Rez.Cookbook.Manifest` handles reading and writing the `cookbook.toml` manifest file.

  Each dependency is a `[[dependency]]` TOML array-of-tables entry with a `module` field,
  optional `version` (defaults to "main"), and `types` list (e.g. ["lib"], ["pragma"],
  or ["lib", "pragma"]).
  """

  alias Rez.Cookbook.Config

  @header """
  # Rez Cookbook Dependencies
  # Run 'rez cookbook list' to see available modules.
  # Run 'rez cookbook get <category/module>' to add a module.
  """

  @doc """
  Reads the manifest and returns `{:ok, [{module_path, version_ref, types}]}` or `{:error, reason}`.
  `types` is a list such as `["lib"]`, `["pragma"]`, or `["lib", "pragma"]`.
  """
  def read(game_root) do
    path = Config.manifest_path(game_root)

    case File.read(path) do
      {:ok, content} -> parse(content)
      {:error, :enoent} -> {:error, "No cookbook.toml found. Run 'rez cookbook init' first."}
      {:error, reason} -> {:error, "Could not read cookbook.toml: #{reason}"}
    end
  end

  @doc """
  Adds or replaces an entry for `module_path` in the manifest.
  `types` is a list such as `["lib"]`, `["pragma"]`, or `["lib", "pragma"]`.
  """
  def put_entry(game_root, module_path, version_ref, types \\ ["lib"]) do
    path = Config.manifest_path(game_root)
    entries = read_entries(path)
    updated = List.keystore(entries, module_path, 0, {module_path, version_ref, types})
    File.write!(path, encode(updated))
  end

  @doc """
  Removes the entry for `module_path` from the manifest.
  """
  def remove_entry(game_root, module_path) do
    path = Config.manifest_path(game_root)
    entries = read_entries(path)
    updated = List.keydelete(entries, module_path, 0)
    File.write!(path, encode(updated))
  end

  @doc """
  Converts an index.json type string to a types list.
  Handles the legacy "both" value from the remote index.
  """
  def index_type_to_list("both"),   do: ["lib", "pragma"]
  def index_type_to_list("pragma"), do: ["pragma"]
  def index_type_to_list(_),        do: ["lib"]

  defp parse(content) do
    case Toml.decode(content) do
      {:ok, %{"dependency" => deps}} when is_list(deps) ->
        entries =
          Enum.map(deps, fn attrs ->
            module_path = Map.fetch!(attrs, "module")
            version_ref = Map.get(attrs, "version", Config.default_ref())
            types = Map.get(attrs, "types", ["lib"])
            {module_path, version_ref, types}
          end)
        {:ok, entries}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, "Could not parse cookbook.toml: #{inspect(reason)}"}
    end
  end

  defp read_entries(path) do
    case File.read(path) do
      {:ok, content} ->
        case parse(content) do
          {:ok, entries} -> entries
          _ -> []
        end
      {:error, _} -> []
    end
  end

  defp encode(entries) do
    blocks =
      entries
      |> Enum.map(fn {module_path, version_ref, types} ->
        version_line =
          if version_ref == Config.default_ref(), do: "", else: ~s|version = "#{version_ref}"\n|

        types_str = Enum.map_join(types, ", ", &~s|"#{&1}"|)
        "[[dependency]]\nmodule = \"#{module_path}\"\n#{version_line}types = [#{types_str}]"
      end)

    @header <> "\n" <> Enum.join(blocks, "\n\n") <> if(entries == [], do: "", else: "\n")
  end
end
