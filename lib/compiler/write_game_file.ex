defmodule Rez.Compiler.WriteGameFile do
  @moduledoc """
  `Rez.Compiler.WriteGameFile` implements the compiler phase that writes the
  game HTML index file using EEx and the embedded game template.
  """

  require EEx

  alias Rez.Compiler.{Compilation, IOError}

  @index_file_name "index.html"

  EEx.function_from_file(:def, :render_index, Path.expand("assets/templates/index.html.eex"), [
    :assigns
  ])

  # @external_resource "assets/templates/index.html.eex"
  # @index_template File.read!("assets/templates/index.html.eex")

  @doc """
  Writes the games index.html template by passing the game through the
  index EEx template
  """
  def run_phase(
        %Compilation{
          status: :ok,
          dist_path: dist_path,
          game: game,
          progress: progress,
          options: %{output: true}
        } = compilation
      ) do
    html = render_index(game: game)

    # html = EEx.eval_string(@index_template, assigns: [game: game])
    output_path = Path.join(dist_path, @index_file_name)

    case File.write(output_path, html) do
      :ok -> %{compilation | progress: ["Written #{output_path}" | progress]}
      {:error, code} -> IOError.file_write_error(compilation, code, "Game file", output_path)
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
