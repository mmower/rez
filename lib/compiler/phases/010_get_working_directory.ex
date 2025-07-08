defmodule Rez.Compiler.Phases.GetWorkingDirectory do
  @moduledoc """
  `Rez.Compiler.GetWorkingDirectory` is the compiler phase that gets the
  directory the compiler has been invoked in.
  """

  alias Rez.Compiler.{Compilation}

  def get_cwd(compilation) do
    case File.cwd() do
      {:ok, current_path} ->
        %{compilation | path: current_path}

      {:error, errno} ->
        Compilation.add_error(compilation, "Unable to get current path: #{errno}")
    end
  end

  @doc """
  Get the working directory
  """
  def run_phase(%Compilation{status: :ok, options: %{wdir: path}} = compilation) do
    case path do
      nil ->
        get_cwd(compilation)

      path ->
        case File.cd(path) do
          :ok ->
            get_cwd(compilation)

          {:error, errno} ->
            Compilation.add_error(
              compilation,
              "Unable to change to working dir #{path}: #{errno}"
            )
        end
    end
  end

  # No :error case is required because this is the first compilation phase
end
