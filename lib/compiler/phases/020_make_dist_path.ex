defmodule Rez.Compiler.Phases.MakeDistPath do
  @moduledoc """
  `Rez.Compiler.MakeDistPath` implements the compiler phase that checks if
  the distribution folder exists and, if not, tries to create it.
  """

  alias Rez.Compiler.{Config, Compilation}

  # As the first function in the pipeline status can never be :error here so
  # Dialyzer complains about this function not being callable.
  # defp get_current_path(%Compilation{status: :error} = compilation) do
  #   compilation
  # end

  @doc """
  Ensure that the dist directory (for the final game files) exists
  """
  def run_phase(
        %Compilation{status: :ok, progress: progress, errors: errors, path: path} = compilation
      ) do
    dist_path = Path.join(path, Config.dist_path_name())

    case File.mkdir_p(dist_path) do
      :ok ->
        %{
          compilation
          | dist_path: dist_path,
            progress: ["Created dist folder: #{dist_path}" | progress]
        }

      {:error, error} ->
        %{
          compilation
          | status: :error,
            errors: ["Unable to create dist folder #{dist_path}: #{error}" | errors]
        }
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
