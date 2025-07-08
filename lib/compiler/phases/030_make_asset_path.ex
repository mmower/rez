defmodule Rez.Compiler.Phases.MakeAssetPath do
  @moduledoc """
  `Rez.Compiler.MakeAssetPath` is the compiler phase that tests whether the
  asset distribution folder exists and, if not, tries to create it.
  """

  alias Rez.Compiler.{Config, Compilation}

  @doc """
  Ensure that the asset path within the dist directory exists
  """
  def run_phase(
        %Compilation{status: :ok, progress: progress, errors: errors, dist_path: dist_path} =
          compilation
      ) do
    asset_path = Path.join(dist_path, Config.asset_path_name())

    case File.mkdir_p(asset_path) do
      :ok ->
        %{compilation | progress: ["Created asset folder: #{asset_path}" | progress]}

      {:error, error} ->
        %{
          compilation
          | status: :error,
            errors: ["Unable to create asset folder #{asset_path}: #{error}" | errors]
        }
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
