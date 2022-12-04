defmodule Rez.Parser.IdentifierParser do
  alias Ergo.Context
  import Ergo.Combinators
  import Ergo.Terminals

  # alias Rez.Parser.ParserCache

  # JSIdentifier

  #
  # Error Handling
  #
  # If you have an identifier like "a1" this fails in the many() parser
  # since it has a min of 2. However this error is a bit inscrutable when
  # you are at the top-level
  #
  # Suggestion: we add an 'err' handler to the Parser that consumes the
  # low-level error and augments it.
  #
  # e.g.
  #
  # err: fn {:error, :many_less_than_min} -> blah
  #         {:error, :unexpected_char} -> blah
  #
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
