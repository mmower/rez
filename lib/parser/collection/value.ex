defmodule Rez.Parser.Collection.Value do
  @moduledoc """
  Implements the parser for a collection value
  """

  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  import Ergo.Combinators, only: [choice: 1]

  import Rez.Parser.ValueParsers, only: [value: 0]
  import Rez.Parser.CollectionParser, only: [collection: 0]

  def collection_value() do
    cached_parser(
      choice([
        value(),
        collection()
      ])
    )
  end
end
