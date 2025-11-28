defmodule Rez.Compiler.Phases.ReprocessAST do
  @moduledoc """
  `Rez.Compiler.ProcessAST` implements the compiler phase that post processes
  the game AST nodes. For example some nodes will converting markup into a
  pre-compiled template.
  """

  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation
  alias Rez.AST.Node

  @doc """
  Runs the Node.pre-process/1 callback on all AST nodes
  """
  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    # We know we're possibly creating temporary files during node processing
    # so ensure they are cleaned up when we exit
    Temp.track!()

    content_data = Map.take(compilation, [:content, :type_map, :id_map])

    %{
      compilation
      | content:
          Enum.map(content, fn node ->
            if NodeHelper.get_meta(node, :processed, false) do
              node
            else
              Node.process(node, content_data)
            end
          end)
    }
  end

  def run_phase(compilation) do
    compilation
  end
end
