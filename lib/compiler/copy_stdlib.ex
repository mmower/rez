defmodule Rez.Compiler.CopyStdlib do
  @moduledoc """
  Compiler phase that copies the stdlib.rez to the src folder
  @todo Something odd about this...
  """
  alias Rez.Compiler.{Config, Compilation, IOError}

  require EEx

  EEx.function_from_file(:def, :render_index, Path.expand("assets/templates/stdlib.rez.eex"), [
    :assigns
  ])

  @stdlib_file_name "stdlib.rez"

  def run_phase(%Compilation{status: :ok, game: game, progress: progress} = compilation) do
    source = render_index(game: game)
    output_path = Path.join(Config.lib_path_name(), @stdlib_file_name)

    case File.write(output_path, source) do
      :ok ->
        %{compilation | progress: ["Written #{output_path}" | progress]}

      {:error, code} ->
        IOError.file_write_error(compilation, code, @stdlib_file_name, output_path)
    end
  end

  def run_phase(%Compilation{} = compilation) do
    compilation
  end
end
