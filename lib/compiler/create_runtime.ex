defmodule Rez.Compiler.CreateRuntime do
  @moduledoc """
  `Rez.Compiler.CreateRuntime` implements the compiler phase that generates
  the contents of the Rez JS runtime.

  """

  require EEx

  alias Rez.Compiler.{Compilation, IOError}

  EEx.function_from_file(:def, :render_runtime, Path.expand("assets/templates/runtime.js.eex"), [
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
    runtime_code = render_runtime(game: game)
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
