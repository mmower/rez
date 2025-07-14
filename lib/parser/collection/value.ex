defmodule Rez.Parser.Collection.Value do
  @moduledoc """
  Implements the parser for a collection value
  """

  alias Rez.Parser.ParserCache

  import Ergo.Combinators, only: [choice: 1]

  import Rez.Parser.ValueParsers, only: [value: 0]
  import Rez.Parser.CollectionParser, only: [collection: 0]

  def collection_value() do
    ParserCache.get_parser("collection_value", fn ->
      choice([
        value(),
        collection()
      ])
    end)
  end
end
