defmodule Rez.Compiler.Phases.WriteGameFile do
  @moduledoc """
  `Rez.Compiler.WriteGameFile` implements the compiler phase that writes the
  game HTML index file using EEx and the embedded game template.
  """

  require EEx

  alias Rez.AST.NodeHelper

  alias Rez.AST.Asset

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.IOError

  EEx.function_from_file(:def, :render_index, Path.expand("assets/templates/index.html.eex"), [
    :assigns
  ])

  @doc """
  Writes the games index.html template by passing the game through the
  index EEx template
  """
  def run_phase(
        %Compilation{
          status: :ok,
          dist_path: dist_path,
          id_map: id_map,
          type_map: type_map,
          progress: progress,
          options: %{output: true}
        } = compilation
      ) do
    game = id_map["game"]

    styles = Map.get(type_map, "style", [])
    scripts = Map.get(type_map, "script", [])
    assets = Map.get(type_map, "asset", [])

    js_pre_runtime_assets = js_pre_runtime_assets(assets)
    js_post_runtime_assets = js_post_runtime_assets(assets)
    style_assets = style_assets(assets)

    html =
      render_index(
        game: game,
        styles: styles,
        scripts: scripts,
        style_assets: style_assets,
        js_pre_runtime_assets: js_pre_runtime_assets,
        js_post_runtime_assets: js_post_runtime_assets
      )

    output_path = Path.join(dist_path, "index.html")

    case File.write(output_path, html) do
      :ok -> %{compilation | progress: ["Written #{output_path}" | progress]}
      {:error, code} -> IOError.file_write_error(compilation, code, "Game file", output_path)
    end
  end

  def run_phase(compilation) do
    compilation
  end

  def js_pre_runtime_assets(assets) do
    assets
    |> Enum.filter(&(Asset.compile_time_script?(&1) && Asset.pre_runtime?(&1)))
  end

  def js_post_runtime_assets(assets) do
    assets
    |> Enum.filter(&(Asset.compile_time_script?(&1) && !Asset.pre_runtime?(&1)))
  end

  def style_assets(assets) do
    assets
    |> Enum.filter(&Asset.style_asset?(&1))
  end
end
