defmodule Rez.Compiler.StartHandlebars do
  @moduledoc """
  `Rez.Compiler.StartsHandlebars` is a compiler phase that determines
  whether the `handlebars` command is avialable for precompiling templates and
  then starts the Handlebars compiler server.
  """
  alias Rez.Compiler.Compilation

  @doc """
  Ensure that the handlebars template pre-processor can be called
  """
  def run_phase(
        %Compilation{status: :ok, progress: progress, errors: errors, cache_path: cache_path} =
          compilation
      ) do
    try do
      {version, 0} = System.cmd("handlebars", ["-v"])
      Rez.Handlebars.start_link(cache_path)
      %{compilation | progress: ["Using handlebars version #{String.trim(version)}" | progress]}
    rescue
      e ->
        %{
          compilation
          | status: :error,
            errors: ["Unable to execute handlebars command: #{Exception.message(e)}" | errors]
        }
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
