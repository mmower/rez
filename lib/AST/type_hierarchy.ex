defmodule Rez.AST.TypeHierarchy do
  @moduledoc """
  Implements the %TypeHierarchy{} struct that is used to store is-a relationships
  between atoms that represent in-game item (and possibly other) types.
  """
  alias __MODULE__

  defstruct is_a: %{}

  def new() do
    %TypeHierarchy{}
  end

  def is_a(_, tag, tag), do: true

  def is_a(%TypeHierarchy{} = hierarchy, tag, parent) when is_binary(tag) and is_binary(parent) do
    search_is_a(hierarchy, tag, parent)
  end

  def add(%TypeHierarchy{is_a: is_a} = type_map, tag, parent) do
    parents =
      Map.get(is_a, tag, MapSet.new())
      |> MapSet.put(parent)

    %{type_map | is_a: Map.put(is_a, tag, parents)}
  end

  def search_is_a(%TypeHierarchy{is_a: is_a} = type_hierarchy, tag, parent) do
    case Map.get(is_a, tag) do
      nil ->
        false

      parents ->
        case MapSet.member?(parents, parent) do
          true ->
            true

          false ->
            Enum.any?(parents, fn search_parent ->
              search_is_a(type_hierarchy, search_parent, parent)
            end)
        end
    end
  end

  @doc """
  Given a type hierarchy and a starting type tag return a list containing all
  possible types. For example:

  @derive :weapon :item
  @derive :sword :weapon
  @derive :magic_word :sword

  TypeHierarchy.expand(hierarchy, :magic_sword) => [:item, :weapon, :magic_sword]
  """
  def expand(%TypeHierarchy{is_a: is_a} = type_hierarchy, tag) do
    case Map.get(is_a, tag) do
      nil ->
        [tag]

      tags ->
        tags
        |> Enum.map(fn tag -> expand(type_hierarchy, tag) end)
        |> Enum.concat(tags)
        |> List.flatten()
        |> Enum.concat([tag])
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
