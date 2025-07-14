defmodule Rez.Parser.Collection.ProbabilityTable do
  @moduledoc """
  Implements parser for probability table attribute values
  """
  alias Ergo.Numeric
  alias Rez.Parser.ParserCache

  import Ergo.Combinators, only: [sequence: 1, sequence: 2, ignore: 1, many: 1]

  import Rez.Parser.UtilityParsers, only: [iows: 0, iws: 0, pipe: 0]
  import Rez.Parser.ValueParsers, only: [value: 0]

  def probability_table() do
    ParserCache.get_parser("probability_table", fn ->
      sequence(
        [
          ignore(pipe()),
          many(
            sequence([
              iows(),
              value(),
              iws(),
              Numeric.uint()
            ])
          ),
          ignore(pipe())
        ],
        ast: fn ast ->
          {:ptable,
           ast
           |> List.flatten(ast)
           |> Enum.chunk_every(2, 2, :discard)
           |> Enum.map(fn [a, b] -> {a, b} end)}
        end
      )
    end)
  end
end
