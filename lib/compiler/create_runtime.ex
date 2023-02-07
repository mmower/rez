defmodule Rez.Compiler.CreateRuntime do
  @moduledoc """
  `Rez.Compiler.CreateRuntime` implements the compiler phase that generates
  the contents of the Rez JS runtime.
  """

  require EEx

  alias Rez.Compiler.{Compilation, IOError}

  alias Rez.AST.{Asset, Game, NodeHelper}

  @js_stdlib Path.wildcard("assets/templates/runtime/rez_*.js")
  |> Enum.sort()
  |> Enum.map(fn file -> File.read!(Path.expand(file)) end)
  |> Enum.join("\n")

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
    :register_handlebars_helpers,
    Path.expand("assets/templates/runtime/register_handlebars_helpers.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :render_runtime,
    Path.expand("assets/templates/runtime.js.eex"), [
    :assigns
  ])

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
          |> NodeHelper.get_attr_value("_path")
          |> File.read!()
        end)
      |> Enum.join("\n\n")

    runtime_code = render_runtime(
      game: game,
      js_stdlib: @js_stdlib,
      js_userlib: js_userlib,
      patch_js_objects: patch_js_objects(game: game),
      init_game_objects: init_game_objects(game: game),
      register_handlebars_helpers: register_handlebars_helpers(game: game)
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
