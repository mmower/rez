defmodule Rez.Parser.TemplateExpressionParser do
  alias Ergo.Combinators, as: EC
  alias Rez.Parser.UtilityParsers, as: UP
  alias Rez.Parser.IdentifierParser, as: IP
  alias Rez.Parser.ValueParsers, as: VP
  alias Rez.Parser.ParserCache, as: PC

  def attribute() do
    EC.sequence(
      [
        IP.js_identifier(),
        EC.ignore(UP.dot()),
        IP.js_identifier()
      ],
      ast: fn [binding, attribute] ->
        {:lookup, binding, attribute}
      end
    )
  end

  def expression_value() do
    EC.choice([
      attribute(),
      VP.string_value(),
      VP.number_value(),
      VP.bool_value()
    ])
  end

  def filter_params() do
    EC.sequence(
      [
        UP.iows(),
        EC.ignore(UP.colon()),
        UP.iws(),
        expression_value(),
        EC.many(
          EC.sequence([
            UP.iows(),
            EC.ignore(UP.comma()),
            UP.iows(),
            expression_value()
          ])
        )
      ],
      ast: &List.flatten/1
    )
  end

  def filter() do
    EC.sequence(
      [
        # filter name
        IP.js_identifier(),
        EC.optional(filter_params())
      ],
      ast: fn
        [name] -> {name, []}
        [name, params] -> {name, params}
      end
    )
  end

  def filters() do
    # 0 or more
    EC.many(
      EC.sequence([
        UP.iows(),
        EC.ignore(UP.bar()),
        UP.iows(),
        filter()
      ]),
      ast: &List.flatten/1
    )
  end

  def expression() do
    EC.sequence(
      [
        UP.iows(),
        expression_value(),
        filters(),
        UP.iows()
      ],
      ast: fn [expression, filters] ->
        {:expression, expression, filters}
      end
    )
  end

  def parser(), do: PC.get_parser("template_expression", fn -> expression() end)

  def parse(s) when is_binary(s) do
    case Ergo.parse(parser(), s) do
      %{status: :ok, ast: ast} ->
        {:ok, ast}

      ctx ->
        {:error, ctx.status}
    end
  end
end
