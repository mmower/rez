defmodule Rez.Parser.DelimitedParser do
  @moduledoc """
  Defines the parsers for parsing delimited text blocks:
  * text_delimited_by_parsers
  * text_delimited_by_nested_parsers
  """
  import Ergo.Terminals
  import Ergo.Combinators

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

  def invalid_pattern_check(nil), do: nil

  def invalid_pattern_check(invalid_parser) when is_function(invalid_parser, 0) do
    sequence([
      invalid_parser.(),
      commit()
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
    trim = Keyword.get(options, :trim, false)
    invalid_parser = Keyword.get(options, :invalid_pattern, nil)

    start_parser =
      if start_open, do: set_counter(counter, 0), else: open(open_parser, counter, :zero)

    # If not invalid_pattern is passed then invalid_pattern_check() will return
    # nil and needs to be removed from the list. This preserves the pre-existing
    # behavior of the t_d_b_n_p parser
    inner_choices =
      [
        open(open_parser, counter, :inc),
        inner_close(close_parser, counter),
        invalid_pattern_check(invalid_parser),
        inner_char(close_parser)
      ]
      |> Enum.reject(&is_nil/1)

    sequence(
      [
        start_parser,
        many(choice(inner_choices)),
        ignore(close_parser)
      ],
      ast: fn chunks ->
        chunks
        |> List.flatten()
        |> List.to_string()
        |> then(&if trim, do: String.trim(&1), else: &1)
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
