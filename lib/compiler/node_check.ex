defmodule Rez.Compiler.NodeCheck do
  @moduledoc """
  Compiler phase that checks for error status in any of the nodes after they
  have been processed and fails the compiler with the collected error info.
  """
  alias Rez.AST.Node
  alias Rez.AST.Game
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, game: game} = compilation) do
    case Enum.reject(Game.all_nodes(game), &(&1.status == :ok)) do
      [] ->
        compilation

      err_nodes when is_list(err_nodes) ->
        Enum.reduce(err_nodes, compilation, fn %{id: node_id, status: {:error, err_info}} = node,
                                               comp2 ->
          case err_info do
            errors when is_list(errors) ->
              Enum.reduce(errors, comp2, fn error, comp3 ->
                Compilation.add_error(
                  comp3,
                  "In #{Node.node_type(node)}/#{node_id}: #{inspect(error)}"
                )
              end)

            error ->
              Compilation.add_error(
                comp2,
                "In #{Node.node_type(node)}/#{node_id}: #{inspect(error)}"
              )
          end
        end)
    end
  end

  def run_phase(compilation) do
    compilation
  end
end
