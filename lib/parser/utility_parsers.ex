defmodule Rez.Parser.UtilityParsers do
  @moduledoc """
  `Rez.Parser.UtilityParsers` implements useful, mostly terminal, parsers
  that are the "connective tissue" of the main parser elements.
  """

  import Ergo.{Combinators, Terminals}
  alias Ergo.Combinators

  require Rez.Parser.ParserCache, as: PC
  alias Rez.Parser.ParserCache

  def upcase_alpha, do: PC.cached_parser(char([?A..?Z], label: "uppercase_alpha"))

  def iws(), do: PC.cached_parser(ignore(many(ws())))

  def iows(), do: PC.cached_parser(optional(iws()))

  def iliteral(s), do: ParserCache.get_parser("iliteral-#{s}", fn -> ignore(literal(s)) end)

  def double_quote(), do: ParserCache.get_parser("double-quote", fn -> char(?") end)

  def not_double_quote(), do: ParserCache.get_parser("not-double-quote", fn -> char(-?") end)

  def equals(), do: ParserCache.get_parser("equals", fn -> char(?=) end)

  def comma(), do: ParserCache.get_parser("comma", fn -> char(?,) end)

  def colon(), do: ParserCache.get_parser("colon", fn -> char(?:) end)

  def hash(), do: ParserCache.get_parser("hash", fn -> char(?#) end)

  def bang(), do: ParserCache.get_parser("bang", fn -> char(?!) end)

  def dollar(), do: ParserCache.get_parser("dollar", fn -> char(?$) end)

  def pipe(), do: ParserCache.get_parser("pipe", fn -> char(?|) end)

  def dot(), do: ParserCache.get_parser("dot", fn -> char(?.) end)

  def plus(), do: ParserCache.get_parser("plus", fn -> char(?+) end)

  def minus(), do: ParserCache.get_parser("minus", fn -> char(?-) end)

  def star(), do: ParserCache.get_parser("star", fn -> char(?*) end)

  def bar(), do: ParserCache.get_parser("bar", fn -> char(?|) end)

  def at(), do: ParserCache.get_parser("at", fn -> char(?@) end)

  def open_brace(), do: ParserCache.get_parser("open_brace", fn -> char(?{) end)

  def close_brace(), do: ParserCache.get_parser("close_brace", fn -> char(?}) end)

  def open_paren(), do: ParserCache.get_parser("open_paren", fn -> char(?() end)

  def close_paren(), do: ParserCache.get_parser("close_paren", fn -> char(?)) end)

  def open_bracket(), do: ParserCache.get_parser("open_bracket", fn -> char(?[) end)

  def close_bracket(), do: ParserCache.get_parser("close_bracket", fn -> char(?]) end)

  def left_angle_bracket(), do: ParserCache.get_parser("left_angle_bracket", fn -> char(?<) end)

  def right_angle_bracket(), do: ParserCache.get_parser("right_angle_bracket", fn -> char(?>) end)

  def back_tick(), do: ParserCache.get_parser("backtick", fn -> char(?`) end)

  def amp(), do: ParserCache.get_parser("ampersand", fn -> char(?&) end)

  def percent(), do: ParserCache.get_parser("percent", fn -> char(?%) end)

  def caret(), do: ParserCache.get_parser("caret", fn -> char(?^) end)

  def forward_slash(), do: ParserCache.get_parser("forward_slash", fn -> char(?/) end)

  def arrow(), do: ParserCache.get_parser("arrow", fn -> literal("=>") end)

  def string() do
    Combinators.many(non_ws(), min: 1, ast: &List.to_string(&1))
  end

  def block_begin(),
    do: ParserCache.get_parser("block_begin", fn -> ignore(open_brace()) end)

  def block_end(),
    do: ParserCache.get_parser("block_end", fn -> ignore(close_brace()) end)

  def elem_start_char(),
    do: ParserCache.get_parser("elem_start_char", fn -> char([?a..?z, ?A..?Z]) end)

  def elem_body_char(),
    do: ParserCache.get_parser("elem_body_char", fn -> char([?_, ?a..?z, ?A..?Z, ?0..?9]) end)

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
