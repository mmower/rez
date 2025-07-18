defmodule Rez.Parser.AttributeParser do
  @moduledoc """
  `Rez.Parser.AttributeParser` implements parsers for attributes and attribute
  values.
  """
  alias Ergo.Context
  import Ergo.Combinators, only: [choice: 2, sequence: 2, ignore: 1]
  import Ergo.Meta, only: [commit: 0]

  import Rez.Parser.UtilityParsers, only: [iws: 0, colon: 0]
  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  alias Rez.Parser.CollectionParser
  alias Rez.Parser.ValueParsers
  alias Rez.Parser.BTreeParser

  alias Rez.Parser.ParserCache

  def attr_value() do
    ParserCache.get_parser("attr_value", fn ->
      choice(
        [
          CollectionParser.collection(),
          ValueParsers.value(),
          BTreeParser.bt_parser()
        ],
        err: fn ctx ->
          ctx
          |> Context.add_error(:bad_value, "Cannot read attribute value")
        end,
        label: "attr-value"
      )
    end)
  end

  def attribute() do
    ParserCache.get_parser("attribute", fn ->
      sequence(
        [
          js_identifier(),
          ignore(colon()),
          iws(),
          commit(),
          attr_value()
        ],
        label: "attribute",
        debug: true,
        err: fn ctx ->
          case ctx.partial_ast do
            [attr_name, nil, nil] ->
              Context.add_error(ctx, :bad_attr, "Unable to read attribute #{attr_name}")

            _ ->
              Context.add_error(ctx, :bad_attr, "Unable to read attribute")
          end
        end,
        ast: fn [id, {type, value}] ->
          %Rez.AST.Attribute{name: id, type: type, value: value}
        end
      )
    end)
  end
end
