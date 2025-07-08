defmodule Rez.Parser.IdentifierParser do
  @moduledoc """
  Implements a parser for legal Javascript identifiers.
  """
  alias Ergo.Context
  import Ergo.Combinators
  import Ergo.Terminals

  def js_identifier(label \\ "js_identifier") do
    Rez.Parser.ParserCache.get_parser("js_identifier##{label}", fn ->
      sequence(
        [
          char([?_, ?$, [?a..?z], [?A..?Z]], label: "js_lead_char"),
          many(char([?_, ?$, [?a..?z], [?A..?Z], [?0..?9]], label: "js_char"))
        ],
        label: label,
        debug: true,
        err: fn %Context{status: {:error, [{code, _, _} | _]}, entry_points: [{line, col} | _]} =
                  ctx ->
          case code do
            :many_less_than_min ->
              Context.add_error(
                ctx,
                :invalid_identifier,
                "Identifiers must be at least 3 characters @ #{line}:#{col}"
              )

            :unexpected_char ->
              Context.add_error(
                ctx,
                :invalid_identifier,
                "Invalid character in identifier @ #{line}:#{col}"
              )

            # Examples are things like :unexpected_eoi that we don't rewrite because it means a valid fail
            _ ->
              ctx
          end
        end,
        ast: fn [first_char, subsequent_chars] ->
          List.to_string([first_char | subsequent_chars])
        end
      )
    end)
  end
end
