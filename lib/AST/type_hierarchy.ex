defmodule Rez.AST.TypeHierarchy do
  alias __MODULE__

  defstruct is_a: %{}

  def new() do
    %TypeHierarchy{}
  end

  def add(%TypeHierarchy{is_a: is_a} = type_map, tag, parent) do
    parents = Map.get(is_a, tag, MapSet.new())
              |> MapSet.put(parent)

    %{type_map | is_a: Map.put(is_a, tag, parents)}
  end

  def search_is_a(%TypeHierarchy{is_a: is_a} = type_hierarchy, tag, parent) do
    case Map.get(is_a, tag) do
      nil ->
        false

      parents ->
        case MapSet.member?(parents, parent) do
          true -> true
          false -> Enum.any?(parents, fn search_parent -> search_is_a(type_hierarchy, search_parent, parent) end)
        end
    end
  end

  def fan_out(%TypeHierarchy{is_a: is_a} = type_hierarchy, tag) do
    case Map.get(is_a, tag) do
      nil ->
        []

      tags ->
        tags
        |> Enum.map(fn tag -> fan_out(type_hierarchy, tag) end)
        |> Enum.concat(tags)
        |> List.flatten()
        |> Enum.uniq()
    end
  end

  def to_json(%TypeHierarchy{is_a: is_a}) do
    is_a
    |> Enum.reduce(%{}, fn {tag, parents}, acc ->
      Map.put(acc, tag, Enum.into(parents, []))
    end)
    |> Poison.encode!()
  end

end
