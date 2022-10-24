defmodule Rez.Compiler.CopyAssets do
  @moduledoc """
  `Rez.Copmiler.CopyAssets` implements the phase of the compiler that copies
  assets from their source path into the "dist" folder of the game.
  """

  alias Rez.Compiler.{Compilation, Config, IOError}
  alias Rez.AST.{Asset, Game, NodeHelper}

  @doc """
  Copies the game asset files into the dist folder
  """
  def run_phase(%Compilation{status: :ok, game: %Game{assets: assets}, options: %{output: true}} = compilation) do
    Enum.reduce(assets, compilation, fn {_id, asset}, acc ->
      copy_asset(acc, asset)
    end)
  end

  def run_phase(compilation) do
    compilation
  end

  def copy_asset(
        %Compilation{status: :ok, dist_path: dist_path} = compilation,
        %Asset{} = asset
      ) do
    if NodeHelper.get_attr_value(asset, "_ignore_missing") do
      compilation
    else
      file_name = Asset.file_name(asset)
      destination_path = Path.join([dist_path, Config.asset_path_name(), file_name])
      asset_path = NodeHelper.get_attr_value(asset, "_path")

      compilation
      |> check_asset_exists(asset_path)
      |> copy_asset_file(asset_path, destination_path)
    end
  end

  def copy_asset(compilation, _asset) do
    compilation
  end

  def check_asset_exists(%Compilation{errors: errors} = compilation, asset_path) do
    case File.exists?(asset_path) || Compilation.ignore_missing_assets?(compilation) do
      true ->
        compilation

      false ->
        %{
          compilation
          | status: :error,
            errors: ["Asset source file #{asset_path} not found." | errors]
        }
    end
  end

  def copy_asset_file(
        %Compilation{status: :ok, progress: progress} = compilation,
        asset_path,
        destination_path
      ) do
    case File.cp(asset_path, destination_path) do
      :ok ->
        %{compilation | progress: ["Copied asset #{asset_path}" | progress]}

      {:error, code} ->
        if Compilation.ignore_missing_assets?(compilation) do
          compilation
        else
          IOError.file_write_error(compilation, code, "Asset", destination_path)
        end
    end
  end

  def copy_asset_file(%Compilation{} = compilation, _asset_path, _destination_path) do
    compilation
  end
end
