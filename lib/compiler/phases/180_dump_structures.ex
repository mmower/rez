defmodule Rez.Compiler.Phases.DumpStructures do
  @moduledoc """
  Implements the dump structures phase of the Rez compiler.

  It writes a pretty-printed version of the list of AST nodes to a file.
  """
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{} = compilation) do
    File.write!(
      "contents.exs",
      "contents = " <> inspect(compilation.content, pretty: true, limit: :infinity)
    )

    compilation
  end
end
