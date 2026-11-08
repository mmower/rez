defmodule Rez.Compiler.Phases.ResolveGroups do
  @moduledoc """
  Resolves each `@group` into the list of asset ids it contains.

  Asset tags and types are fixed at compile time, so a group's membership can
  be computed here rather than at runtime. The ids are stored in the group's
  `values` attribute and the group is emitted as a `RezList` (see
  `Rez.AST.Node.js_initializer/1` for `Rez.AST.Group`).

  An asset is a member of a group when:
  - its type (the first part of its MIME type) matches the group's `type`
  - it has *any* of the group's `include_tags` (if any are given)
  - it has *none* of the group's `exclude_tags` (if any are given)

  Template assets are ignored. A group that matches no assets is a compile
  error.
  """
  alias Rez.AST.Asset
  alias Rez.AST.Group
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    assets =
      content
      |> Enum.filter(&match?(%Asset{}, &1))
      |> Enum.reject(&NodeHelper.template_node?/1)

    {content, compilation} =
      Enum.map_reduce(content, compilation, fn
        %Group{} = group, compilation -> resolve_group(group, assets, compilation)
        node, compilation -> {node, compilation}
      end)

    %{
      compilation
      | content: content,
        progress: ["Resolved asset groups" | compilation.progress]
    }
  end

  def run_phase(compilation), do: compilation

  defp resolve_group(%Group{} = group, assets, compilation) do
    if NodeHelper.template_node?(group) do
      {group, compilation}
    else
      case matching_asset_ids(group, assets) do
        [] ->
          {group, Compilation.add_error(compilation, no_match_error(group))}

        ids ->
          values = Enum.map(ids, &{:string, &1})
          {NodeHelper.set_list_attr(group, "values", values), compilation}
      end
    end
  end

  @doc """
  Returns the sorted ids of the assets that are members of the group.
  """
  def matching_asset_ids(%Group{} = group, assets) do
    type = keyword_value(NodeHelper.get_attr_value(group, "type"))
    include_tags = tag_set(group, "include_tags")
    exclude_tags = tag_set(group, "exclude_tags")

    assets
    |> Enum.filter(fn asset ->
      tags = tag_set(asset, "tags")

      asset_type(asset) == type &&
        (Enum.empty?(include_tags) || !MapSet.disjoint?(tags, include_tags)) &&
        MapSet.disjoint?(tags, exclude_tags)
    end)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  defp asset_type(%Asset{} = asset) do
    mime_type =
      case NodeHelper.get_attr_value(asset, "$detected_mime_type") do
        nil ->
          asset
          |> NodeHelper.get_attr_value("file_name", NodeHelper.get_attr_value(asset, "file_path"))
          |> mime_from_path()

        mime_type ->
          mime_type
      end

    mime_type |> String.split("/") |> List.first()
  end

  defp mime_from_path(nil), do: ""
  defp mime_from_path(path), do: MIME.from_path(path)

  defp tag_set(node, attr_name) do
    case NodeHelper.get_attr_value(node, attr_name) do
      %MapSet{} = tags -> tags
      _ -> MapSet.new()
    end
  end

  defp keyword_value({:keyword, value}), do: value
  defp keyword_value(value) when is_binary(value), do: value
  defp keyword_value(_), do: nil

  defp no_match_error(%Group{id: id} = group) do
    type = keyword_value(NodeHelper.get_attr_value(group, "type"))

    "@group #{id} (type: :#{type}#{describe_tags(group, "include_tags")}#{describe_tags(group, "exclude_tags")}) matches no assets"
  end

  defp describe_tags(group, attr_name) do
    case tag_set(group, attr_name) |> Enum.map(&keyword_value/1) |> Enum.sort() do
      [] -> ""
      tags -> ", #{attr_name}: " <> Enum.map_join(tags, " ", &":#{&1}")
    end
  end
end
