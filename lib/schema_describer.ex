defmodule Rez.SchemaDescriber do
  @moduledoc """
  `Rez.SchemaDescriber` implements the `rez schema` command which describes
  the attributes an element accepts, based on the `@schema`, `@defaults`, and
  `@elem` definitions in the stdlib and, optionally, in a game's source.

    rez schema                    # list elements with a schema (stdlib)
    rez schema card               # describe @card (stdlib)
    rez schema game.rez           # list elements, including game schemas
    rez schema game.rez my_elem   # describe an element using game schemas
  """

  alias Rez.AST.{Alias, Schema}
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.{BuildSchema, CopyStdlib, GetWorkingDirectory, ParseSource, ReadSource}
  alias Rez.Compiler.CommentMacro
  alias Rez.Compiler.SchemaBuilder.SchemaRule
  alias Rez.Parser.Parser

  defmodule Spec do
    @moduledoc """
    The schema information needed to describe elements: schema rules by
    element name, defaults by element name, aliases by alias name, and the
    names of elements whose schema came from the game (rather than stdlib).
    """
    defstruct schema: %{}, defaults: %{}, aliases: %{}, game_elements: MapSet.new()
  end

  @doc """
  Entry point for `rez schema`. Returns `:ok` or `:error`.
  """
  def run(args, options \\ %{}) do
    {source, rest} = split_args(args)

    case load(source, options) do
      {:ok, spec} ->
        print_result(spec, rest)

      {:error, errors} ->
        IO.puts("rez v#{Rez.version()} — unable to read schema")
        Enum.each(errors, &IO.puts(format_error(&1)))
        :error
    end
  end

  # The first argument is the game source if it ends in .rez
  defp split_args([first | rest] = args) do
    if String.ends_with?(first, ".rez"), do: {first, rest}, else: {nil, args}
  end

  defp split_args([]), do: {nil, []}

  defp print_result(spec, []) do
    IO.puts(list_elements(spec))
    :ok
  end

  defp print_result(spec, [elem | _]) do
    case describe(spec, elem) do
      {:ok, text} ->
        IO.puts(text)
        :ok

      {:error, reason} ->
        IO.puts(reason)
        :error
    end
  end

  defp format_error({elem, id, error}), do: "In #{elem}##{id}: #{error}"
  defp format_error(error), do: to_string(error)

  @doc """
  Loads the schema from the stdlib (when `source` is nil) or from a game
  source file which is expected to include the stdlib. Nothing is written to
  disk.
  """
  def load(source, options \\ %{})

  def load(nil, _options) do
    with {:ok, nodes} <- parse_stdlib() do
      {:ok, spec_from_nodes(nodes, MapSet.new())}
    end
  end

  def load(source_path, options) when is_binary(source_path) do
    options = Map.merge(%{write_source: false, verbose: 0, wdir: nil}, options)

    compilation =
      [GetWorkingDirectory, ReadSource, ParseSource]
      |> Enum.reduce(
        %Compilation{source_path: source_path, options: options},
        &Rez.Compiler.run_phase/2
      )

    with %Compilation{status: :ok, content: content} <- compilation,
         {:ok, stdlib_nodes} <- parse_stdlib() do
      stdlib_elements =
        stdlib_nodes
        |> Enum.filter(&is_struct(&1, Schema))
        |> MapSet.new(& &1.element)

      game_elements =
        content
        |> Enum.filter(&is_struct(&1, Schema))
        |> MapSet.new(& &1.element)
        |> MapSet.difference(stdlib_elements)

      {:ok, spec_from_nodes(content, game_elements)}
    else
      %Compilation{errors: errors} -> {:error, Enum.reverse(errors)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses a source string (rather than a file) and returns the schema spec.
  Mainly useful for testing.
  """
  def load_string(source) when is_binary(source) do
    with {:ok, nodes} <- parse_string(source, "game.rez") do
      {:ok, spec_from_nodes(nodes, MapSet.new())}
    end
  end

  defp parse_stdlib() do
    parse_string(CopyStdlib.render_stdlib(content: []), "stdlib.rez")
  end

  defp parse_string(source, file_name) do
    logical_file =
      source
      |> Rez.Utils.dummy_source(file_name)
      |> CommentMacro.process_comments()

    case Parser.parse(logical_file) do
      {:ok, content, _id_map, _keywords} ->
        {:ok, content}

      {:error, reasons, line, col, _input} ->
        {:error, ["#{file_name} L#{line}:#{col} #{inspect(reasons)}"]}
    end
  end

  defp spec_from_nodes(nodes, game_elements) do
    %Compilation{schema: schema, defaults: defaults} =
      BuildSchema.run_phase(%Compilation{content: nodes})

    aliases =
      nodes
      |> Enum.filter(&is_struct(&1, Alias))
      |> Map.new(&{&1.name, &1.target})

    %Spec{schema: schema, defaults: defaults, aliases: aliases, game_elements: game_elements}
  end

  @doc """
  Returns the chain of element names from the most specific (the given name)
  to the base element, e.g. "item" -> ["item", "object"].
  """
  def alias_chain(%Spec{aliases: aliases}, name), do: alias_chain(aliases, name, [])

  defp alias_chain(aliases, name, seen) do
    case Map.get(aliases, name) do
      nil ->
        [name]

      target ->
        if name in seen, do: [name], else: [name | alias_chain(aliases, target, [name | seen])]
    end
  end

  @doc """
  Returns a text listing of all elements that have a schema, and all aliases.
  """
  def list_elements(%Spec{schema: schema, aliases: aliases, game_elements: game_elements}) do
    elements =
      schema
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn elem ->
        if MapSet.member?(game_elements, elem), do: "  @#{elem}  (game)", else: "  @#{elem}"
      end)

    alias_lines =
      aliases
      |> Enum.sort()
      |> Enum.map(fn {name, target} -> "  @#{name} = #{target}" end)

    [
      "Elements with a schema:",
      elements,
      if(alias_lines == [], do: [], else: ["", "Aliases (@elem):" | alias_lines]),
      "",
      "Use `rez schema [game.rez] <element>` to describe an element's attributes."
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  @doc """
  Describes the attributes of the named element (with or without a leading
  `@`), merging schema rules and defaults along its alias chain.
  """
  def describe(%Spec{schema: schema, defaults: defaults} = spec, elem) do
    name = String.trim_leading(elem, "@")
    chain = alias_chain(spec, name)

    rules =
      chain
      |> Enum.flat_map(&Map.get(schema, &1, []))
      |> List.flatten()

    if rules == [] do
      {:error,
       "No schema found for @#{name}. Run `rez schema` to list the elements that have one."}
    else
      merged_defaults =
        chain
        |> Enum.reverse()
        |> Enum.reduce(%{}, fn target, acc -> Map.merge(acc, Map.get(defaults, target, %{})) end)

      {:ok, render(name, chain, rules, merged_defaults)}
    end
  end

  defp render(name, chain, rules, defaults) do
    {schema_rules, pattern_rules} = Enum.split_with(rules, &is_struct(&1, SchemaRule))

    attr_exprs =
      schema_rules
      |> Enum.reject(&is_nil(&1.attr))
      |> Enum.group_by(& &1.attr, & &1.expr)
      |> Map.new(fn {attr, exprs} -> {attr, Enum.uniq(exprs)} end)

    # Attributes may have a default without any schema rules
    attr_exprs =
      Enum.reduce(Map.keys(defaults), attr_exprs, &Map.put_new(&2, &1, []))

    rows =
      attr_exprs
      |> Enum.sort_by(fn {attr, exprs} -> sort_key(attr, exprs) end)
      |> Enum.map(fn {attr, exprs} -> attr_row(attr, exprs, Map.get(defaults, attr)) end)

    pattern_rows =
      pattern_rules
      |> Enum.group_by(&Regex.source(&1.pattern), & &1.expr)
      |> Enum.sort()
      |> Enum.map(fn {pattern, exprs} -> attr_row("/#{pattern}/", Enum.uniq(exprs), nil) end)

    header =
      case chain do
        [_] -> "@#{name}"
        _ -> "@#{name}  (#{Enum.join(chain, " -> ")})"
      end

    [
      header,
      format_rows(rows),
      if(pattern_rows == [],
        do: [],
        else: ["", "Attributes matching a pattern:", format_rows(pattern_rows)]
      )
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp sort_key(attr, exprs) do
    group =
      cond do
        String.starts_with?(attr, "$") -> 2
        {:required, true} in exprs -> 0
        true -> 1
      end

    {group, attr}
  end

  defp attr_row(attr, exprs, default) do
    {kind, exprs} = take_expr(exprs, :kind)
    {coll_kind, exprs} = take_expr(exprs, :coll_kind)
    {required, exprs} = take_expr(exprs, :required)

    type =
      case {kind, coll_kind} do
        {nil, nil} -> ""
        {kinds, nil} -> Enum.join(kinds, "|")
        {nil, ckinds} -> "<#{Enum.join(ckinds, "|")}>"
        {kinds, ckinds} -> "#{Enum.join(kinds, "|")}<#{Enum.join(ckinds, "|")}>"
      end

    notes =
      [
        if(required in [true, {:boolean, true}], do: "required"),
        if(default, do: "default #{render_value(default)}")
        | Enum.map(exprs, &render_expr/1)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    {attr, type, notes}
  end

  defp take_expr(exprs, key) do
    case Enum.split_with(exprs, &(is_tuple(&1) and elem(&1, 0) == key)) do
      {[], rest} -> {nil, rest}
      {[expr | _], rest} -> {elem(expr, 1), rest}
    end
  end

  defp format_rows([]), do: []

  defp format_rows(rows) do
    attr_width = rows |> Enum.map(&String.length(elem(&1, 0))) |> Enum.max()
    type_width = rows |> Enum.map(&String.length(elem(&1, 1))) |> Enum.max()

    Enum.map(rows, fn {attr, type, notes} ->
      String.trim_trailing(
        "  #{String.pad_trailing(attr, attr_width)}  #{String.pad_trailing(type, type_width)}  #{notes}"
      )
    end)
  end

  defp render_expr({:ref_elem, elems}) when is_list(elems),
    do: "ref_elem: #{Enum.map_join(elems, "|", &"@#{&1}")}"

  # The parser discards the type of `in:` values so render them bare
  defp render_expr({:in, values}) when is_list(values),
    do: "in: #{Enum.join(values, "|")}"

  defp render_expr({:is_a, elem, attr}), do: "is_a: @#{elem}/#{attr}"

  # Some rules are stored under a different name to the one used in @schema
  defp render_expr({:min_value, value}), do: "min: #{render_literal(value)}"
  defp render_expr({:max_value, value}), do: "max: #{render_literal(value)}"

  defp render_expr({key, value}) when is_list(value),
    do: "#{key}: #{Enum.map_join(value, " ", &render_literal/1)}"

  defp render_expr({key, value}), do: "#{key}: #{render_literal(value)}"

  defp render_expr(expr) when is_tuple(expr) do
    [key | values] = Tuple.to_list(expr)
    "#{key}: #{Enum.map_join(values, " ", &render_literal/1)}"
  end

  defp render_expr(expr) when is_atom(expr), do: to_string(expr)
  defp render_expr(expr), do: inspect(expr)

  defp render_literal(value) when is_binary(value), do: inspect(value)
  defp render_literal(value) when is_atom(value), do: ":#{value}"
  defp render_literal({type, _} = value) when is_atom(type), do: render_value(value)
  defp render_literal(value), do: inspect(value)

  @doc """
  Renders an attribute value (an `%Attribute{}` or a `{type, value}` tuple)
  back into Rez literal syntax where possible.
  """
  def render_value(%{type: type, value: value}), do: render_value({type, value})
  def render_value({:boolean, value}), do: to_string(value)
  def render_value({:number, value}), do: to_string(value)
  def render_value({:string, value}), do: inspect(value)
  def render_value({:keyword, value}), do: ":#{value}"
  def render_value({:elem_ref, value}), do: "##{value}"
  def render_value({:const_ref, value}), do: "$#{value}"
  def render_value({:elem_name, value}), do: "@#{value}"
  def render_value({:placeholder, _}), do: "_"
  def render_value({:delegate, attr}), do: "^d:#{attr}"
  def render_value({:source_template, _}), do: "<template>"

  def render_value({:list, values}) when is_list(values),
    do: "[#{Enum.map_join(values, " ", &render_value/1)}]"

  def render_value({type, %MapSet{} = values}) when type in [:set, :merge_set] do
    "\#{#{values |> Enum.map(&render_value/1) |> Enum.sort() |> Enum.join(" ")}}"
  end

  def render_value({:table, values}) when is_map(values) do
    entries =
      values
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join(" ", fn {k, v} -> "#{k}: #{render_value(v)}" end)

    "{#{entries}}"
  end

  def render_value({:function, _}), do: "<function>"
  def render_value({type, _}) when is_atom(type), do: "<#{type}>"
  def render_value(value) when is_atom(value), do: ":#{value}"
  def render_value(value) when is_binary(value), do: inspect(value)
  def render_value(value), do: inspect(value)
end
