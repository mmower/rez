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

  def attr_value() do
    choice(
      [
        CollectionParser.collection(),
        ValueParsers.value(),
        BTreeParser.bt_parser()
      ],
      err: fn ctx ->
        Context.add_error(ctx, "Cannot read attribute value")
      end,
      label: "attr-value"
    )
  end

  def attribute() do
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
      ast: fn [id, {type, value}] ->
        %Rez.AST.Attribute{name: id, type: type, value: value}
      end
    )
  end
end
