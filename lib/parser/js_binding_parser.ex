defmodule Rez.Parser.JSBindingParser do
  @moduledoc """
  Implements a parser for Javascript binding expressions, e.g.
  foo.bar.baz -> ["foo", "bar", "baz"]

  Also supports bracket notation for array indices and string keys:
  - arr[0] -> ["arr", {:index, 0}]
  - obj["key"] -> ["obj", {:key, "key"}]
  - arr[idx] -> ["arr", {:bound_index, ["idx"]}]
  - matrix[row][col] -> ["matrix", {:bound_index, ["row"]}, {:bound_index, ["col"]}]
  """
  import Ergo.Combinators, only: [sequence: 1, sequence: 2, many: 1, ignore: 1, choice: 1]
  import Rez.Parser.UtilityParsers, only: [dot: 0, open_bracket: 0, close_bracket: 0, iows: 0]
  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]
  import Rez.Parser.ValueParsers, only: [number_value: 0, string_value: 0]
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  @doc """
  Parses a literal numeric index like [0] or [42]
  """
  def literal_index() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          number_value(),
          iows(),
          ignore(close_bracket())
        ],
        ast: fn [{:number, n}] -> {:index, trunc(n)} end
      )
    )
  end

  @doc """
  Parses a string key like ["key"] or ["special-key"]
  """
  def string_key() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          string_value(),
          iows(),
          ignore(close_bracket())
        ],
        ast: fn [{:string, s}] -> {:key, s} end
      )
    )
  end

  @doc """
  Parses a bound variable index like [idx] or [row.col]
  """
  def bound_index() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          js_identifier(),
          many(sequence([ignore(dot()), js_identifier()])),
          iows(),
          ignore(close_bracket())
        ],
        ast: fn path -> {:bound_index, List.flatten(path)} end
      )
    )
  end

  @doc """
  Parses any bracket access: [0], ["key"], or [varname]
  Order matters: try literal number first, then string, then identifier (fallback)
  """
  def bracket_access() do
    cached_parser(
      choice([
        literal_index(),
        string_key(),
        bound_index()
      ])
    )
  end

  @doc """
  Parses a single path segment: either .identifier or bracket access
  """
  def path_segment() do
    cached_parser(
      choice([
        sequence([ignore(dot()), js_identifier()]),
        bracket_access()
      ])
    )
  end

  @doc """
  Parses a full binding path like foo.bar[0].baz or arr[idx]
  """
  def binding_path() do
    cached_parser(
      sequence(
        [
          js_identifier(),
          many(path_segment())
        ],
        ast: fn ast ->
          {:bound_path, List.flatten(ast)}
        end
      )
    )
  end
end
