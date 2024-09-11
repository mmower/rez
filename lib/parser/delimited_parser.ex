defmodule Rez.Parser.DelimitedParser do
  import Ergo.{Terminals, Combinators}

  alias Ergo.Context

  import Ergo.Parser, only: [terminal: 3]

  import Ergo.Combinators,
    only: [sequence: 1, sequence: 2, many: 1, choice: 1, ignore: 1, not_lookahead: 1]

  import Ergo.Terminals, only: [any: 0]
  import Ergo.Meta, only: [commit: 0]

  def set_counter(counter_name, value) do
    terminal(
      :set_counter,
      "Set-Counter:#{counter_name} = #{value}",
      fn %Context{} = ctx ->
        counters = Map.get(ctx, :counters, %{})
        Map.put(ctx, :counters, Map.put(counters, counter_name, value))
      end
    )
  end

  def inc_counter(counter_name) do
    terminal(
      :inc_counter,
      "Inc-Counter:#{counter_name}",
      fn %Context{} = ctx ->
        counters = Map.get(ctx, :counters, %{})
        Map.put(ctx, :counters, Map.update(counters, counter_name, 1, &(&1 + 1)))
      end
    )
  end

  def dec_counter(counter_name) do
    terminal(
      :dec_counter,
      "Dec-Counter:#{counter_name}",
      fn %Context{} = ctx ->
        counters = Map.get(ctx, :counters, %{})
        Map.put(ctx, :counters, Map.update(counters, counter_name, -1, &(&1 - 1)))
      end
    )
  end

  def open(open_parser, counter_name, :zero) do
    sequence([
      ignore(open_parser),
      set_counter(counter_name, 0)
    ])
  end

  def open(open_parser, counter_name, :inc) do
    sequence([
      open_parser,
      inc_counter(counter_name)
    ])
  end

  def inner_close(close_parser, counter_name) do
    sequence([
      non_zero_counter(counter_name),
      close_parser,
      dec_counter(counter_name)
    ])
  end

  def inner_char(close_parser) do
    sequence([
      not_lookahead(close_parser),
      any()
    ])
  end

  def non_zero_counter(counter_name) do
    terminal(
      :non_zero_counter,
      "Test-Counter-Non-Zero:#{counter_name}",
      fn %Context{} = ctx ->
        counters = Map.get(ctx, :counters, %{})

        case Map.get(counters, counter_name) do
          nil ->
            %{ctx | status: {:error, "Counter #{counter_name} is not defined!"}}

          0 ->
            %{ctx | status: {:error, "Counter #{counter_name} is 0"}}

          _ ->
            %{ctx | status: :ok}
        end
      end
    )
  end

  def text_delimited_by_prefix_and_nested_parsers(
        prefix_parser,
        open_parser,
        close_parser,
        _options \\ []
      ) do
    sequence([
      prefix_parser,
      commit(),
      text_delimited_by_nested_parsers(open_parser, close_parser)
    ])
  end

  def text_delimited_by_nested_parsers(open_parser, close_parser, options \\ []) do
    counter = "#{:erlang.unique_integer([:monotonic, :positive])}"
    start_open = Keyword.get(options, :start_open, false)

    start_parser =
      if start_open, do: set_counter(counter, 0), else: open(open_parser, counter, :zero)

    sequence(
      [
        start_parser,
        many(
          choice([
            open(open_parser, counter, :inc),
            inner_close(close_parser, counter),
            inner_char(close_parser)
          ])
        ),
        ignore(close_parser)
      ],
      ast: fn chunks ->
        chunks |> List.flatten() |> List.to_string()
      end
    )
  end

  @doc """
  ## Examples
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals}
      iex> import Rez.Parser.Parser
      iex> p = text_delimited_by_parsers(literal("begin"), literal("end"))
      iex> input = "begin this is some text between delimiters end"
      iex> assert %Context{status: :ok, ast: " this is some text between delimiters ", input: ""} = Ergo.parse(p, input)
  """
  def text_delimited_by_parsers(open_parser, close_parser, options \\ []) do
    trim = Keyword.get(options, :trim, false)

    sequence(
      [
        ignore(open_parser),
        many(
          sequence(
            [
              not_lookahead(close_parser),
              any()
            ],
            ast: &List.first/1
          )
        ),
        ignore(close_parser)
      ],
      label: "delimited-text",
      ast: fn chars ->
        str = List.to_string(chars)

        case trim do
          true -> String.trim(str)
          false -> str
        end
      end
    )
  end
end
