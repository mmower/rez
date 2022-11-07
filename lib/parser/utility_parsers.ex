defmodule Rez.Parser.UtilityParsers do
  @moduledoc """
  `Rez.Parser.UtilityParsers` implements useful, mostly terminal, parsers
  that are the "connective tissue" of the main parser elements.
  """

  import Ergo.{Combinators, Terminals}

  def iws(), do: ignore(many(ws()), label: "WS")

  def iows(), do: optional(iws(), label: "WS")

  def iliteral(string), do: ignore(literal(string))

  def double_quote(), do: char(?")

  def not_double_quote(), do: char(-?")

  def equals(), do: char(?=)

  def comma(), do: char(?,)

  def colon(), do: char(?:)

  def hash(), do: char(?#)

  def dollar(), do: char(?$)

  def dot(), do: char(?.)

  def open_brace(), do: char(?{)

  def close_brace(), do: char(?})

  def open_paren(), do: char(?()

  def close_paren(), do: char(?))

  def open_bracket(), do: char(?[)

  def close_bracket(), do: char(?])

  def caret(), do: char(?^)

  def forward_slash(), do: char(?/)

  def arrow(), do: sequence([char(?=), char(?>)], label: "=>")

  def block_begin(block_type), do: ignore(literal("begin"), label: "IGN #{block_type} begin")

  def block_end(block_type), do: ignore(literal("end"), label: "IGN #{block_type} end")

  def elem_start_char(), do: char([?a..?z])

  def elem_body_char(), do: char([?_, ?a..?z])

  def elem_tag() do
    sequence(
      [
        elem_start_char(),
        many(elem_body_char())
      ],
      ast: &(&1 |> List.flatten() |> List.to_string()),
      label: "elem_tag")
  end

end
