defmodule Rez.Exporter do
  @moduledoc """
  `Rez.Exporter` implements the `rez export` subcommand.

  Compiles the game up through the final AST transformation phase (with all
  defaults, constants, and schema applied) then filters elements by kind and
  writes a CSV of their scalar attributes to stdout.

  Usage: rez export @<kind>
  """

  alias Rez.Compiler
  alias Rez.AST.NodeHelper

  @scalar_types [:number, :string, :boolean, :keyword]

  def export([], _options) do
    IO.puts(:stderr, "Usage: rez export @<kind>")
    :error
  end

  def export([kind_arg | rest], options) do
    kind = String.trim_leading(kind_arg, "@")
    game_root = Map.get(options, :wdir) || File.cwd!()

    case find_source(rest, game_root) do
      {:ok, source_path} ->
        IO.puts(:stderr, "Compiling #{source_path}...")
        compilation = Compiler.compile_to_struct(source_path, options)
        do_export(kind, compilation)

      {:error, reason} ->
        IO.puts(:stderr, reason)
        :error
    end
  end

  defp do_export(kind, compilation) do

    case compilation.status do
      :error ->
        Enum.each(compilation.errors, &IO.puts(:stderr, &1))
        :error

      :ok ->
        elements = filter_by_kind(compilation, kind)
        IO.puts(:stderr, "Found #{length(elements)} elements of kind '#{kind}'")
        write_csv(elements)
    end
  end

  defp find_source([path | _], _game_root) when byte_size(path) > 0 do
    expanded = Path.expand(path)

    if File.regular?(expanded) do
      {:ok, expanded}
    else
      {:error, "Source file not found: #{expanded}"}
    end
  end

  defp find_source(_, game_root) do
    dir_name = Path.basename(game_root)
    candidate = Path.join(game_root, "#{dir_name}.rez")

    if File.regular?(candidate) do
      {:ok, candidate}
    else
      case Path.wildcard(Path.join(game_root, "*.rez")) do
        [found | _] -> {:ok, found}
        [] -> {:error, "No .rez source file found in #{game_root}. Pass the path explicitly: rez export @<kind> path/to/game.rez"}
      end
    end
  end

  defp filter_by_kind(%{content: content}, kind) do
    Enum.filter(content, fn node ->
      node.game_element == true && node_has_kind?(node, kind)
    end)
  end

  defp node_has_kind?(node, kind) do
    case NodeHelper.get_attr_value(node, "$kinds", []) do
      kinds when is_list(kinds) ->
        Enum.any?(kinds, fn
          {:string, k} -> k == kind
          k when is_binary(k) -> k == kind
          _ -> false
        end)

      _ ->
        false
    end
  end

  @exportable_types @scalar_types ++ [:elem_ref, :roll]

  defp scalar_attr?({name, %{type: t}}) do
    !String.starts_with?(name, "$") && t in @exportable_types
  end

  defp scalar_attr?(_), do: false

  defp attr_to_string(%{type: :elem_ref, value: v}), do: to_string(v)
  defp attr_to_string(%{type: :keyword, value: v}), do: to_string(v)
  defp attr_to_string(%{type: :boolean, value: v}), do: to_string(v)
  defp attr_to_string(%{type: :number, value: v}), do: to_string(v)
  defp attr_to_string(%{type: :string, value: v}), do: to_string(v)
  defp attr_to_string(%{type: :roll, value: {count, sides, 0, 1}}),
    do: "#{count}d#{sides}"
  defp attr_to_string(%{type: :roll, value: {count, sides, mod, 1}}) when mod > 0,
    do: "#{count}d#{sides}+#{mod}"
  defp attr_to_string(%{type: :roll, value: {count, sides, mod, 1}}),
    do: "#{count}d#{sides}#{mod}"
  defp attr_to_string(%{type: :roll, value: {count, sides, 0, rounds}}),
    do: "#{count}d#{sides}:#{rounds}"
  defp attr_to_string(%{type: :roll, value: {count, sides, mod, rounds}}) when mod > 0,
    do: "#{count}d#{sides}+#{mod}:#{rounds}"
  defp attr_to_string(%{type: :roll, value: {count, sides, mod, rounds}}),
    do: "#{count}d#{sides}#{mod}:#{rounds}"

  defp write_csv([]) do
    IO.puts(:stderr, "No matching elements found.")
    :ok
  end

  defp write_csv(elements) do
    columns =
      elements
      |> Enum.flat_map(fn el ->
           el.attributes
           |> Enum.filter(&scalar_attr?/1)
           |> Enum.map(fn {name, _} -> name end)
         end)
      |> Enum.uniq()
      |> Enum.sort()

    [["id" | columns] | build_rows(elements, columns)]
    |> CSV.encode()
    |> Enum.each(&IO.write/1)

    :ok
  end

  defp build_rows(elements, columns) do
    Enum.map(elements, fn el ->
      values =
        Enum.map(columns, fn col ->
          case Map.get(el.attributes, col) do
            nil -> ""
            attr -> if scalar_attr?({col, attr}), do: attr_to_string(attr), else: ""
          end
        end)

      [el.id | values]
    end)
  end
end
