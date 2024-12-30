defmodule Rez.Compiler.WriteObjMap do
  require EEx

  alias Rez.Compiler.Compilation

  alias Rez.AST.Node
  alias Rez.AST.Patch

  @doc """
  Writes the games index.html template by passing the game through the
  index EEx template
  """
  def run_phase(
        %Compilation{
          status: :ok,
          game: game,
          options: %{write_obj_map: true}
        } = compilation
      ) do
    Enum.each(Node.children(game), fn
      %Patch{} = patch ->
        case Patch.type(patch) do
          :function -> IO.puts("Patch #{Patch.object(patch)}.#{Patch.function(patch)}")
          :method -> IO.puts("Patch #{Patch.object(patch)}.#{Patch.method(patch)}")
        end

      %{id: id} = node ->
        IO.puts("#{Node.node_type(node)}/#{id}")

      _ ->
        nil
    end)

    compilation
  end

  def run_phase(compilation) do
    compilation
  end
end
