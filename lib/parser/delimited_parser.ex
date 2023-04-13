defmodule Rez.Parser.DelimitedParser do
  import Ergo.{Terminals, Combinators}

  @doc """
  ## Examples
      iex> alias Ergo.Context
      iex> import Ergo.{Terminals}
      iex> import Rez.Parser.Parser
      iex> p = text_delimited_by_parsers(literal("begin"), literal("end"))
      iex> input = "begin this is some text between delimiters end"
      iex> assert %Context{status: :ok, ast: " this is some text between delimiters ", input: ""} = Ergo.parse(p, input)
  """
  def text_delimited_by_parsers(open_parser, close_parser, options \\ []) do
    trim = Keyword.get(options, :trim, false)

    sequence(
      [
        ignore(open_parser),
        many(
          sequence(
            [
              not_lookahead(close_parser),
              any()
            ],
            ast: &List.first/1
          )
        ),
        ignore(close_parser)
      ],
      label: "delimited-text",
      ast: fn chars ->
        str = List.to_string(chars)

        case trim do
          true -> String.trim(str)
          false -> str
        end
      end
    )
  end
end
