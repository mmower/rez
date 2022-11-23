defmodule Rez.Utils do
  @moduledoc """
  `Rez.Utils` contains utility/helper functions for working with structs,
  strings, list, and so on.
  """

  def ellipsize(str, max \\ 40) when is_binary(str) and max > 3 do
    if String.length(str) > max do
      String.slice(str, 0..(max - 4)) <> "..."
    else
      str
    end
  end

  def append_str(str, tail) do
    str <> tail
  end

  @doc """
  Given a struct returns a lookup key for that struct type, e.g.
  Rez.AST.Scene becomes 'scenes' and Rez.AST.Inventory becomes 'inventories'
  """
  def struct_key(s) do
    s
    |> struct_name()
    |> Inflectorex.pluralize()
    |> String.to_atom()
  end

  @doc """
  Given a struct return the struct name, e.g. Rez.AST.Scene becomes 'scene'.
  """

  def struct_name(s) do
    s.__struct__
    |> Module.split()
    |> List.last()
    |> String.downcase()
  end

  @doc """
  Given a map and a list of keys return a list containing keys that are not
  present in the map.

  ## Examples
      iex> import Rez.Utils, only: [missing_keys: 2]
      iex> m = %{a: 1, c: 3}
      iex> assert [:b] = missing_keys(m, [:a, :b, :c])
  """
  def missing_keys(target_map, keys) when is_map(target_map) and is_list(keys) do
    Enum.filter(keys, fn key -> !Map.has_key?(target_map, key) end)
  end

  @doc ~S"""
  Given a map and a function return a map whose values are the values of the original
  map with the function applied to it.

  ## Examples
      iex> import Rez.Utils, only: [map_to_map: 2]
      iex> m = %{a: 1, b: 2, c: 3}
      iex> assert %{a: 2, b: 4, c: 6} = map_to_map(m, fn x -> 2 * x end)
  """
  def map_to_map(map, map_fn) when is_map(map) and is_function(map_fn) do
    map
    |> Enum.map(fn {key, value} -> {key, map_fn.(value)} end)
    |> Enum.into(%{})
  end

  def update(map, key, default, f) when is_map(map) and is_function(f) do
    updated_val =
      map
      |> Map.get(key, default)
      |> f.()

    Map.put(map, key, updated_val)
  end

  def attr_list_to_map(attr_list) when is_list(attr_list) do
    Enum.reduce(attr_list, %{}, fn attr, attr_map ->
      Map.put(attr_map, attr.name, attr)
    end)
  end

  @doc ~S"""
  Split a string into a list of lines suitable for processing.

  ## Examples
      iex> import Rez.Utils
      iex> assert ["", "  one two", "    three", ""] = string_to_lines("\n  one two\n    three\n")
  """
  def string_to_lines(s) when is_binary(s) do
    String.split(s, ["\n", "\r", "\r\n"])
  end

  def wrap_with(s, front, back) do
    front <> s <> back
  end

  @doc ~S"""
  Appends the contents of the list `from_list` to the end of list `to_list`.
  This function is intended for use in |> since you can't easily pipe ++
  """
  def append(to, from) when is_list(to) and is_list(from) do
    to ++ from
  end

  @doc ~S"""
  Generate a short-randomised string, e.g.:
    ABKR6H1HCENF9
    3EODQGCD0MRA3
    2JKGI112I9MA58

    From an answer to generating ids:
    https://stackoverflow.com/questions/44082348/creating-uuids-in-elixir
    by https://stackoverflow.com/users/575642/cdegroot
  """
  def random_str() do
    Integer.to_string(:rand.uniform(4294967296), 32) <> Integer.to_string(:rand.uniform(4294967296), 32)
  end

end
