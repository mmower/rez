defmodule Rez.Compiler.ProcessAST do
  @moduledoc """
  `Rez.Compiler.ProcessAST` implements the compiler phase that post processes
  the game AST nodes. For example some nodes will converting markup into a
  pre-compiled template.
  """

  alias Rez.Compiler.Compilation
  alias Rez.AST.Node

  @doc """
  Runs the Node.pre-process/1 callback on all AST nodes
  """
  def run_phase(%Compilation{status: :ok, game: game} = compilation) do
    # We know we're possibly creating temporary files during node processing
    # so ensure they are cleaned up when we exit
    Temp.track!()
    %{compilation | game: Node.process(game)}
  end

  def run_phase(compilation) do
    compilation
  end
end
