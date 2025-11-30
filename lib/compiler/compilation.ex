defmodule Rez.Compiler.Compilation do
  alias __MODULE__
  alias Rez.AST.Game

  alias Rez.AST.TypeHierarchy

  import Rez.Utils, only: [path_is_sub_path?: 2]

  defmodule PluginAPI do
    use Lua.API, scope: "rez.compilation"

    deflua main_source_path(compilation), state do
      {:userdata, compilation} = Lua.decode!(state, compilation)
      compilation.source_path
    end

    deflua source_paths(compilation, user_only \\ false), state do
      {:userdata, compilation} = Lua.decode!(state, compilation)

      sources =
        compilation.source.sections
        |> Enum.reduce(MapSet.new(), fn {_range, section}, sources ->
          source_path = Path.expand(section.source_path, compilation.source_path)

          if user_only do
            if path_is_sub_path?(source_path, compilation.source.base_path) do
              MapSet.put(sources, source_path)
            else
              sources
            end
          else
            MapSet.put(sources, source_path)
          end
        end)
        |> MapSet.to_list()

      Lua.encode_list!(state, [sources])
    end

    deflua add_content(compilation, content_to_add), state do
      {:userdata, compilation} = Lua.decode!(state, compilation)
      {:userdata, content_to_add} = Lua.decode!(state, content_to_add)

      content_list = compilation.content
      content_list = [content_to_add | content_list]
      compilation = %{compilation | content: content_list}

      Lua.encode!(state, {:userdata, compilation})
    end

    deflua dist_path(compilation), state do
      {:userdata, compilation} = Lua.decode!(state, compilation)
      compilation.dist_path
    end

    deflua get_content_with_id(compilation, id), state do
      {:userdata, compilation} = Lua.decode!(state, compilation)

      case Compilation.content_with_id(compilation, id) do
        nil ->
          nil

        content ->
          Lua.encode!(state, {:userdata, content})
      end
    end
  end

  @moduledoc """
  `Rez.Compiler.Compilation` defines the `Compilation` struct.

  `Compilation` is used to track progress of the compiler and its results.
  """
  defstruct status: :ok,
            game: nil,
            options: %{},
            phase: nil,
            source: nil,
            source_path: nil,
            path: nil,
            dist_path: nil,
            cache_path: nil,
            content: [],
            id_map: %{},
            type_map: %{},
            type_hierarchy: TypeHierarchy.new(),
            defaults: %{},
            aliases: %{},
            constants: %{},
            schema: nil,
            pragmas: [],
            progress: [],
            errors: []

  def set_game(%Compilation{} = compilation, %Game{} = game) do
    %{compilation | game: game}
  end

  def add_error(%__MODULE__{errors: errors} = compilation, error) do
    %{compilation | status: :error, errors: [error | errors]}
  end

  def verbose?(%__MODULE__{options: %{verbose: flag}}), do: flag

  def ignore_missing_assets?(%__MODULE__{options: %{ignore_missing_assets: flag}}), do: flag

  def content_with_id(%__MODULE__{content: content}, id) do
    content |> Enum.filter(&Map.has_key?(&1, :id)) |> Enum.find(&(&1.id == id))
  end
end
