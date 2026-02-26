defmodule Rez.Compiler.Phases.ExpandTagRefs do
  @moduledoc """
  Expands `{:elem_name, "typename"}` entries in `$init_after` attributes into
  individual `{:elem_ref, id}` entries for all elements declared with that tag.

  A tag ref `@typename` matches all game elements whose declared-as tag is
  `typename`:
  - Elements declared directly as `@card` are matched by `@card`
  - Elements declared as `@location` (an alias for card) are matched by `@location`
  - `@card` does NOT include `@location` elements

  Self-references are silently removed. Unknown tag names silently expand to
  empty (no error). Runs before ApplySchema so only `{:elem_ref, _}` items
  remain in `$init_after` by the time schema validation occurs.
  """
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    tag_to_ids = build_tag_to_ids_map(content)

    %{
      compilation
      | content: Enum.map(content, &expand_node(&1, tag_to_ids)),
        progress: ["Expanded tag refs in $init_after" | compilation.progress]
    }
  end

  def run_phase(compilation), do: compilation

  defp build_tag_to_ids_map(content) do
    content
    |> Enum.filter(fn node -> Map.has_key?(node, :id) && node.game_element == true end)
    |> Enum.group_by(fn node ->
      case NodeHelper.get_attr_value(node, "$alias", nil) do
        nil -> Node.node_type(node)
        alias_name -> alias_name
      end
    end)
    |> Map.new(fn {tag, nodes} ->
      {tag, Enum.map(nodes, fn n -> {:elem_ref, n.id} end)}
    end)
  end

  defp expand_node(%{game_element: true} = node, tag_to_ids) do
    case NodeHelper.get_attr_value(node, "$init_after", []) do
      [] ->
        node

      values ->
        if Enum.any?(values, &match?({:elem_name, _}, &1)) do
          expanded =
            values
            |> Enum.flat_map(fn
              {:elem_ref, _} = ref -> [ref]
              {:elem_name, tag} -> Map.get(tag_to_ids, tag, [])
            end)
            |> Enum.reject(fn {:elem_ref, id} -> id == Map.get(node, :id) end)
            |> Enum.uniq()

          NodeHelper.set_list_attr(node, "$init_after", expanded)
        else
          node
        end
    end
  end

  defp expand_node(node, _tag_to_ids), do: node
end
