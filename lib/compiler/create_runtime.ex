defmodule Rez.Compiler.CreateRuntime do
  @moduledoc """
  `Rez.Compiler.CreateRuntime` implements the compiler phase that generates
  the contents of the Rez JS runtime.
  """

  require EEx

  alias Rez.Compiler.{Compilation, IOError}

  alias Rez.AST.{Asset, Game, NodeHelper}

  @js_stdlib_dir "assets/templates/runtime"
  @js_stdlib_files Path.join([@js_stdlib_dir, "rez_*.js"])
                   |> Path.wildcard()
                   |> Enum.sort()
                   |> Enum.map(&Path.expand/1)
  for file <- @js_stdlib_files, do: @external_resource(file)
  @js_stdlib Enum.map_join(@js_stdlib_files, "\n", &File.read!/1)

  EEx.function_from_file(
    :def,
    :init_game_objects,
    Path.expand("assets/templates/runtime/init_game_objects.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :patch_js_objects,
    Path.expand("assets/templates/runtime/patch_js_objects.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :register_expression_filters,
    Path.expand("assets/templates/runtime/register_expression_filters.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :bind_keys,
    Path.expand("assets/templates/runtime/bind_keys.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :user_components,
    Path.expand("assets/templates/runtime/user_components.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :render_runtime,
    Path.expand("assets/templates/runtime.js.eex"),
    [
      :assigns
    ]
  )

  @doc """
  Runs the game runtime template over the Game AST node.
  """
  def run_phase(
        %Compilation{
          status: :ok,
          game: game,
          dist_path: dist_path,
          progress: progress,
          options: %{output: true}
        } = compilation
      ) do
    js_userlib =
      game
      |> Game.js_runtime_assets()
      |> Enum.map(fn %Asset{} = asset ->
        asset
        |> NodeHelper.get_attr_value("$path")
        |> File.read!()
      end)
      |> Enum.join("\n\n")

    runtime_code =
      render_runtime(
        game: game,
        js_stdlib: @js_stdlib,
        js_userlib: js_userlib,
        patch_js_objects: patch_js_objects(game: game),
        bind_keys: bind_keys(game: game),
        user_components: user_components(game: game),
        init_game_objects: init_game_objects(game: game),
        register_expression_filters: register_expression_filters(game: game)
      )

    output_path = Path.join(dist_path, "assets/runtime.js")

    case File.write(output_path, runtime_code) do
      :ok -> %{compilation | progress: ["Written runtime to #{output_path}" | progress]}
      {:error, code} -> IOError.file_write_error(compilation, code, "runtime.js", output_path)
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
