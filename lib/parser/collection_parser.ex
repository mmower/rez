defmodule Rez.Parser.CollectionParser do
  @moduledoc """
  Defines the parsers that parse collection values
  * binding_list
  * list
  * set
  * probability_table
  """
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  alias Rez.Parser.Collection.Set
  alias Rez.Parser.Collection.BindingList
  alias Rez.Parser.Collection.List
  alias Rez.Parser.Collection.ProbabilityTable

  import Ergo.Combinators, only: [choice: 1, lazy: 1]

  def collection() do
    cached_parser(
      choice([
        BindingList.binding_list(),
        Set.merge_set(),
        Set.set(),
        ProbabilityTable.probability_table(),
        lazy(List.list())
      ])
    )
  end
end
