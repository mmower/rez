defmodule Rez.Parser.Collection.Table do
  @moduledoc """
  A Parser that parses table attribute values:
  {key: value ...}
  """

  import Rez.Parser.ParserCache, only: [cached_parser: 1]
  import Ergo.Combinators, only: [sequence: 2, optional: 1, many: 1, ignore: 1, lazy: 1]

  import Rez.Parser.UtilityParsers,
    only: [iws: 0, iows: 0, open_brace: 0, close_brace: 0]

  import Rez.Parser.AttributeParser, only: [attribute: 0]
  import Rez.Utils, only: [attr_list_to_map: 1]

  @doc """
  Returns a parser for table values: `{ key: value ... }`
  """
  def table() do
    cached_parser(
      sequence(
        [
          ignore(open_brace()),
          iows(),
          optional(many(sequence([iws(), lazy(attribute())], ast: &List.first/1))),
          iows(),
          ignore(close_brace())
        ],
        label: "table-value",
        ast: fn attrs -> {:table, attr_list_to_map(List.flatten(attrs))} end
      )
    )
  end
end
