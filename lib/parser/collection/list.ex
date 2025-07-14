defmodule Rez.Parser.Collection.List do
  @moduledoc """
  Implements the parser for list data structures
  [... [...nested list...]]
  """

  alias Rez.Parser.ParserCache

  import Ergo.Combinators, only: [sequence: 1, sequence: 2, optional: 1, many: 1, ignore: 1]

  import Rez.Parser.UtilityParsers,
    only: [iows: 0, iws: 0, open_bracket: 0, close_bracket: 0, comma: 0]

  import Rez.Parser.Collection.Value, only: [collection_value: 0]

  def list() do
    ParserCache.get_parser("list", fn ->
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          optional(
            sequence([
              collection_value(),
              many(
                sequence([
                  iws(),
                  ignore(optional(sequence([comma(), iws()]))),
                  collection_value()
                ])
              )
            ])
          ),
          iows(),
          ignore(close_bracket())
        ],
        label: "list-value",
        debug: true,
        ast: fn list -> {:list, List.flatten(list)} end
      )
    end)
  end
end
