defmodule Rez.Parser.CollectionParser do
  @moduledoc """
  Defines the parsers that parse collection values
  * binding_list
  * list
  * set
  * probability_table
  """
  alias Rez.Parser.ParserCache

  alias Rez.Parser.Collection.Set
  alias Rez.Parser.Collection.BindingList
  alias Rez.Parser.Collection.List
  alias Rez.Parser.Collection.ProbabilityTable

  import Ergo.Combinators, only: [choice: 1, lazy: 1]

  def collection() do
    ParserCache.get_parser("collection", fn ->
      choice([
        BindingList.binding_list(),
        Set.set(),
        ProbabilityTable.probability_table(),
        lazy(List.list())
      ])
    end)
  end
end
