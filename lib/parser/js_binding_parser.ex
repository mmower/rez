defmodule Rez.Parser.JSBindingParser do
  @moduledoc """
  Implements a parser for Javascript binding expressions, e.g.
  foo.bar.baz -> ["foo", "bar", "baz"]
  """
  import Ergo.Combinators, only: [sequence: 1, sequence: 2, many: 1, ignore: 1]
  import Rez.Parser.UtilityParsers, only: [dot: 0]
  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  def binding_path() do
    sequence(
      [
        js_identifier(),
        many(
          sequence([
            ignore(dot()),
            js_identifier()
          ])
        )
      ],
      ast: fn ast ->
        {:bound_path, List.flatten(ast)}
      end
    )
  end
end
