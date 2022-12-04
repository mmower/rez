defmodule Rez.Parser.UtilityParsers do
  @moduledoc """
  `Rez.Parser.UtilityParsers` implements useful, mostly terminal, parsers
  that are the "connective tissue" of the main parser elements.
  """

  import Ergo.{Combinators, Terminals}
  alias Ergo.Combinators

  require Rez.Parser.ParserCache, as: PC
  alias Rez.Parser.ParserCache

  def iws(), do: PC.cached_parser(ignore(many(ws())))

  def iows(), do: PC.cached_parser(optional(iws()))

  def iliteral(s), do: ParserCache.get_parser("iliteral-#{s}", fn -> ignore(literal(s)) end)

  def double_quote(), do: ParserCache.get_parser("double-quote", fn -> char(?") end)

  def not_double_quote(), do: ParserCache.get_parser("not-double-quote", fn -> char(-?") end)

  def equals(), do: ParserCache.get_parser("equals", fn -> char(?=) end)

  def comma(), do: ParserCache.get_parser("comma", fn -> char(?,) end)

  def colon(), do: ParserCache.get_parser("colon", fn -> char(?:) end)

  def hash(), do: ParserCache.get_parser("hash", fn -> char(?#) end)

  def dollar(), do: ParserCache.get_parser("dollar", fn -> char(?$) end)

  def dot(), do: ParserCache.get_parser("dot", fn -> char(?.) end)

  def plus(), do: ParserCache.get_parser("plus", fn -> char(?+) end)

  def minus(), do: ParserCache.get_parser("minus", fn -> char(?-) end)

  def at(), do: char(?@)

  def open_brace(), do: char(?{)

  def close_brace(), do: char(?})

  def open_paren(), do: char(?()

  def close_paren(), do: char(?))

  def open_bracket(), do: char(?[)

  def close_bracket(), do: char(?])

  def right_angle_bracket(), do: char(?>)

  def amp(), do: char(?&)

  def caret(), do: char(?^)

  def forward_slash(), do: char(?/)

  def arrow(), do: literal("=>")

  def block_begin(_block_type), do: ignore(literal("begin"))

  def block_end(_block_type), do: ignore(literal("end"))

  def elem_start_char(), do: ParserCache.get_parser("elem_start_char", fn -> char([?a..?z]) end)

  def elem_body_char(), do: ParserCache.get_parser("elem_body_char", fn -> char([?_, ?a..?z]) end)

  def elem_tag() do
    Combinators.sequence(
      [
        elem_start_char(),
        many(elem_body_char())
      ],
      ast: &(&1 |> List.flatten() |> List.to_string()),
      label: "elem_tag"
    )
  end
end
