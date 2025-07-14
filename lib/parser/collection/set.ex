defmodule Rez.Parser.Collection.Set do
  @moduledoc """
  A Parser that parses set attribute values:
  \#{:a :b}
  """

  alias Rez.Parser.ParserCache

  import Ergo.Combinators, only: [sequence: 1, sequence: 2, optional: 1, many: 1, ignore: 1]

  import Rez.Parser.UtilityParsers,
    only: [iws: 0, iows: 0, hash: 0, open_brace: 0, close_brace: 0]

  import Rez.Parser.ValueParsers, only: [value: 0]

  @doc """
  Returns a parsing for parsing set values.
  """
  def set() do
    ParserCache.get_parser("set_parser", fn ->
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
    end)
  end
end
