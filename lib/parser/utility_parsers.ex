defmodule Rez.Parser.UtilityParsers do
  @moduledoc """
  `Rez.Parser.UtilityParsers` implements useful, mostly terminal, parsers
  that are the "connective tissue" of the main parser elements.
  """

  import Ergo.{Combinators, Terminals}
  alias Ergo.Combinators

  import Rez.Parser.ParserCache, only: [cached_parser: 1]
  alias Rez.Parser.ParserCache

  def upcase_alpha, do: cached_parser(char([?A..?Z], label: "uppercase_alpha"))

  def iws(), do: cached_parser(ignore(many(ws())))

  def iows(), do: cached_parser(optional(iws()))

  def iliteral(s), do: ParserCache.get_parser("iliteral_#{s}", fn -> ignore(literal(s)) end)

  def double_quote(), do: cached_parser(char(?"))

  def not_double_quote(), do: cached_parser(char(-?"))

  def equals(), do: cached_parser(char(?=))

  def comma(), do: cached_parser(char(?,))

  def colon(), do: cached_parser(char(?:))

  def hash(), do: cached_parser(char(?#))

  def bang(), do: cached_parser(char(?!))

  def dollar(), do: cached_parser(char(?$))

  def pipe(), do: cached_parser(char(?|))

  def dot(), do: cached_parser(char(?.))

  def plus(), do: cached_parser(char(?+))

  def minus(), do: cached_parser(char(?-))

  def star(), do: cached_parser(char(?*))

  def bar(), do: cached_parser(char(?|))

  def at(), do: cached_parser(char(?@))

  def open_brace(), do: cached_parser(char(?{))

  def close_brace(), do: cached_parser(char(?}))

  def open_paren(), do: cached_parser(char(?())

  def close_paren(), do: cached_parser(char(?)))

  def open_bracket(), do: cached_parser(char(?[))

  def close_bracket(), do: cached_parser(char(?]))

  def left_angle_bracket(), do: cached_parser(char(?<))

  def right_angle_bracket(), do: cached_parser(char(?>))

  def back_tick(), do: cached_parser(char(?`))

  def amp(), do: cached_parser(char(?&))

  def percent(), do: cached_parser(char(?%))

  def caret(), do: cached_parser(char(?^))

  def forward_slash(), do: cached_parser(char(?/))

  def arrow(), do: cached_parser(literal("=>"))

  def string() do
    cached_parser(Combinators.many(non_ws(), min: 1, ast: &List.to_string(&1)))
  end

  def block_begin(),
    do: cached_parser(ignore(open_brace()))

  def block_end(),
    do: cached_parser(ignore(close_brace()))

  def elem_start_char(),
    do: cached_parser(char([?a..?z, ?A..?Z]))

  def elem_body_char(),
    do: cached_parser(char([?_, ?a..?z, ?A..?Z, ?0..?9]))

  def elem_tag() do
    cached_parser(
      Combinators.sequence(
        [
          elem_start_char(),
          many(elem_body_char())
        ],
        ast: &(&1 |> List.flatten() |> List.to_string()),
        label: "elem_tag"
      )
    )
  end
end
