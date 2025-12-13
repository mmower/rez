defmodule Rez.Parser.Collection.Set do
  @moduledoc """
  A Parser that parses set attribute values:
  \#{:a :b}
  """

  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  import Ergo.Combinators, only: [sequence: 1, sequence: 2, optional: 1, many: 1, ignore: 1]

  import Rez.Parser.UtilityParsers,
    only: [iws: 0, iows: 0, hash: 0, plus: 0, open_brace: 0, close_brace: 0]

  import Rez.Parser.ValueParsers, only: [value: 0]

  @doc """
  Returns a parsing for parsing set values.
  """
  def set() do
    cached_parser(
      sequence(
        [
          ignore(hash()),
          ignore(open_brace()),
          iows(),
          optional(
            sequence([
              value(),
              many(
                sequence([
                  iws(),
                  value()
                ])
              )
            ])
          ),
          iows(),
          ignore(close_brace())
        ],
        label: "set-value",
        debug: true,
        ast: fn set -> {:set, MapSet.new(List.flatten(set))} end
      )
    )
  end

  @doc ~S"""
  Returns a parser for merge set values (+#{...}).
  Unions with any existing set during defaults/mixin application.
  """
  def merge_set() do
    cached_parser(
      sequence(
        [
          ignore(plus()),
          set()
        ],
        label: "merge-set-value",
        ast: fn [{:set, values}] -> {:merge_set, values} end
      )
    )
  end
end
