defmodule Rez.Compiler.WriteObjMap do
  require EEx

  alias Rez.Compiler.Compilation

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
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
    game
    |> Node.children()
    |> Enum.filter(fn node ->
      !NodeHelper.get_attr_value(node, "$built_in", false)
    end)
    |> Enum.group_by(&node_type/1)
    |> Enum.filter(&printable_group/1)
    |> Enum.each(&print_group/1)

    compilation
  end

  def run_phase(compilation) do
    compilation
  end

  def printable_group({{"script", _}, _}), do: false
  def printable_group({{"style", _}, _}), do: false
  def printable_group(_), do: true

  def print_group({{type, nil}, nodes_of_type}) do
    IO.puts("--[#{type} (#{Enum.count(nodes_of_type)})]----")
    Enum.each(nodes_of_type, &print_node/1)
    IO.puts("")
  end

  def print_group({{type, alias}, nodes_of_type}) do
    IO.puts("--[#{alias} -> #{type} (#{Enum.count(nodes_of_type)})]----")
    Enum.each(nodes_of_type, &print_node/1)
    IO.puts("")
  end

  def print_node(%Patch{} = patch) do
    case Patch.type(patch) do
      :function -> IO.puts("@patch #{Patch.object(patch)}.#{Patch.function(patch)}")
      :method -> IO.puts("@patch #{Patch.object(patch)}.#{Patch.method(patch)}")
    end
  end

  def print_node(%{id: id} = node) do
    {file, line, _col} = node.position
    file = Path.relative_to_cwd(file)
    IO.puts("#{node_type_name(node)} ##{id} — #{file}:#{line}")
  end

  def print_node(_) do
  end

  def node_type_name(node) do
    NodeHelper.get_attr_value(node, "$alias", Node.node_type(node))
  end

  def node_type(node) do
    {Node.node_type(node), NodeHelper.get_attr_value(node, "$alias")}
  end
end
