defmodule Rez.Compiler.AddDefaultAssets do
  @moduledoc """
  `Rez.Compiler.AddDefaultAssets` defines the compiler phase that adds
  the "built-in" game assets such as AlpineJS, Handlebars, and BulmaCSS.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.{Asset, Game, Node, NodeHelper}

  @default_assets [
    {"_alpine_js", "alpinejs.min.js"},
    {"_bulma_css", "bulma.min.css"},
    {"_handlebars_js", "handlebars.min.js"}
  ]

  def game_with_assets(game, assets) do
    Enum.reduce(assets, game, fn {asset_name, asset_file}, game ->
      create_asset(asset_name, asset_file)
      |> Game.add_child(game)
    end)
  end

  defp create_asset(id, file_name) do
    %Asset{id: id, position: {"_internal", 0, 0}}
    |> NodeHelper.set_string_attr("file_name", file_name)
    |> Node.pre_process()
  end

  @doc """
  Adds default assets:
    Bulma CSS
    Alpine.JS
    Handlebars
  """
  def run_phase(%Compilation{status: :ok, game: game, options: %{output: true}} = compilation) do
    %{compilation | game: game_with_assets(game, @default_assets)}
  end

  def run_phase(compilation) do
    compilation
  end
end
