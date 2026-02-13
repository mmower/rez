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

  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  def attr_value() do
    cached_parser(
      choice(
        [
          CollectionParser.collection(),
          ValueParsers.value(),
          BTreeParser.bt_parser()
        ],
        err: fn %Context{status: {code, _}, line: line, col: col} = ctx ->
          message =
            "Expected an attribute value, for example: " <>
              ~s|true/false, 42, "text", :keyword, #element_id, $constant, | <>
              "[list], function() {}, ```template```"

          %{ctx | ast: nil, status: {code, [{:bad_value, {line, col}, message}]}}
        end,
        label: "attr-value"
      )
    )
  end

  def attribute() do
    cached_parser(
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
              Context.add_error(ctx, :bad_attr, "Unable to read value for attribute '#{attr_name}'")

            _ ->
              Context.add_error(ctx, :bad_attr, "Unable to read attribute")
          end
        end,
        ast: fn [id, {type, value}] ->
          %Rez.AST.Attribute{name: id, type: type, value: value}
        end
      )
    )
  end
end
