defmodule Rez.Utils do
  @moduledoc """
  `Rez.Utils` contains utility/helper functions for working with structs,
  strings, list, and so on.
  """

  def bounded(value, lower_bound, upper_bound) do
    max(lower_bound, min(upper_bound, value))
  end

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

  def english_list(items, connector \\ ", ")

  def english_list([item], _connector) do
    item
  end

  def english_list([item1, item2], connector) do
    "#{item1}#{connector}#{item2}"
  end

  def english_list(items, connector) when is_list(items) do
    {first_items, [last_item]} = Enum.split(items, -1)
    Enum.join(first_items, ", ") <> connector <> " " <> last_item
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
  def append_list(to, from) when is_list(to) and is_list(from) do
    to ++ from
  end

  def append_list(lst, e) when is_list(lst) and not is_list(e) do
    lst ++ [e]
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
    Integer.to_string(:rand.uniform(4_294_967_296), 32) <>
      Integer.to_string(:rand.uniform(4_294_967_296), 32)
  end

  def file_ctime!(file_path) do
    File.stat!(file_path).ctime
  end

  def add_css_class(classes, ""), do: classes
  def add_css_class(classes, new_class), do: "#{classes} #{new_class}"

  @doc """
  The `dummy_source/3` function converts a string into a `LogicalFile` with
  a fake file name (defaults to 'test.rez') and path (defaults to '.').
  """
  def dummy_source(input, file \\ "test.rez", base_path \\ ".") do
    lines = String.split(input, ~r/\n/, trim: true)
    section = LogicalFile.Section.new(file, 1..Enum.count(lines), lines, 0)
    LogicalFile.assemble(base_path, [section])
  end

  @js_reserved_keywords [
    "abstract",
    "arguments",
    "await",
    "boolean",
    "break",
    "byte",
    "case",
    "catch",
    "char",
    "class",
    "const",
    "continue",
    "debugger",
    "default",
    "delete",
    "do",
    "double",
    "else",
    "enum",
    "eval",
    "export",
    "extends",
    "false",
    "final",
    "finally",
    "float",
    "for",
    "function",
    "goto",
    "if",
    "implements",
    "import",
    "in",
    "instanceof",
    "int",
    "interface",
    "let",
    "long",
    "native",
    "new",
    "null",
    "package",
    "private",
    "protected",
    "public",
    "return",
    "short",
    "static",
    "super",
    "switch",
    "synchronized",
    "this",
    "throw",
    "throws",
    "transient",
    "true",
    "try",
    "typeof",
    "var",
    "void",
    "volatile",
    "while",
    "with",
    "yield"
  ]

  @doc """
  Converts a Unix file name into a legal JavaScript identifier.
  - Removes file extension
  - Replaces invalid characters with underscores
  - Ensures it doesn't start with a digit
  - Ensures it's not a JavaScript reserved keyword
  """
  def file_name_to_js_identifier(file_name) do
    # Remove file extension if present
    base_name = file_name |> String.split(".") |> List.first()

    # Replace invalid characters with underscores
    identifier = Regex.replace(~r/[^a-zA-Z0-9_$]/, base_name, "_")

    # Ensure it doesn't start with a digit
    identifier = if Regex.match?(~r/^\d/, identifier), do: "_" <> identifier, else: identifier

    # Check if it's a reserved keyword and prefix with underscore if needed
    if identifier in @js_reserved_keywords, do: "_" <> identifier, else: identifier
  end

  def path_readable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{access: access}} when access in [:read, :read_write] ->
        :ok

      {:ok, %File.Stat{}} ->
        {:error, "#{path} is unreadable"}

      {:error, reason} ->
        {:error, "#{path}: #{reason}"}
    end
  end

  def path_is_sub_path?(path, parent_path) do
    parent_segments = Path.split(parent_path)
    path_segments = Path.split(path)
    List.starts_with?(path_segments, parent_segments)
  end
end
