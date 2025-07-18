defmodule Rez.Parser.TemplateExpressionParser do
  @moduledoc """
  Defines the parser that parses a template expression used in a source template
  for example "${content}"
  """
  import Ergo.Combinators,
    only: [
      sequence: 1,
      sequence: 2,
      many: 1,
      many: 2,
      choice: 2,
      ignore: 1,
      optional: 1,
      lazy: 1
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  import Rez.Parser.UtilityParsers,
    only: [open_bracket: 0, close_bracket: 0, comma: 0, colon: 0, iws: 0, iows: 0, bar: 0]

  import Rez.Parser.ValueParsers, only: [string_value: 0, number_value: 0, bool_value: 0]
  import Rez.Parser.ParserCache, only: [get_parser: 2]

  def js_value() do
    choice(
      [
        string_value(),
        number_value(),
        bool_value()
      ],
      label: "tep-js-value"
    )
  end

  @doc ~S"""
    iex> import Rez.Parser.TemplateExpressionParser, only: [js_array: 0]
    iex> assert %{status: :ok, ast: {:list, []}} = Ergo.parse(js_array(), "[    ]")
    iex> assert %{status: :ok, ast: {:list, [{:string, "foo"}]}} = Ergo.parse(js_array(), "[\"foo\"]")
    iex> assert %{status: :ok, ast: {:list, [{:number, 1}, {:number, 2}, {:number, 3}]}} = Ergo.parse(js_array(), "[1, 2, 3]")
  """
  def js_array() do
    sequence(
      [
        ignore(open_bracket()),
        iows(),
        optional(lazy(js_value_or_array())),
        optional(
          many(
            sequence([
              iows(),
              ignore(comma()),
              iows(),
              lazy(js_value_or_array())
            ])
          )
        ),
        iows(),
        ignore(close_bracket())
      ],
      ast: fn elements ->
        {:list, List.flatten(elements)}
      end
    )
  end

  def js_value_or_array() do
    choice(
      [
        js_value(),
        js_array()
      ],
      label: "tep-value-or-array"
    )
  end

  import Rez.Parser.JSBindingParser, only: [binding_path: 0]

  def expression_value() do
    choice(
      [
        binding_path(),
        js_value_or_array()
      ],
      label: "tep-expression-value"
    )
  end

  def filter_params() do
    sequence(
      [
        iows(),
        ignore(colon()),
        iws(),
        expression_value(),
        many(
          sequence([
            iows(),
            ignore(comma()),
            iows(),
            expression_value()
          ])
        )
      ],
      ast: &List.flatten/1
    )
  end

  @doc """
    iex> import Rez.Parser.TemplateExpressionParser, only: [filter: 0]
    iex> assert %{status: :ok, ast: {"bsel", [{:list, [number: 1, number: 2, number: 3]}]}} = Ergo.parse(filter(), "bsel: [1, 2, 3]")
  """
  def filter() do
    sequence(
      [
        # filter name
        js_identifier(),
        optional(filter_params())
      ],
      ast: fn
        [name] -> {name, []}
        [name, params] -> {name, params}
      end
    )
  end

  def filters() do
    # 0 or more
    many(
      sequence([
        iows(),
        ignore(bar()),
        iows(),
        filter()
      ]),
      ast: &List.flatten/1
    )
  end

  @doc ~S"""
    iex> import Rez.Parser.TemplateExpressionParser, only: [expression: 0]
    iex> expr = "player.age | gte: 18 | bsel: [\"adult\", \"minor\"]"
    iex> assert %{status: :ok, ast: {:expression, {:bound_path, ["player", "age"]}, [{"gte", [{:number, 18}]}, {"bsel", [{:list, [{:string, "adult"}, {:string, "minor"}]}]}]}} = Ergo.parse(expression(), expr)
  """
  def expression() do
    sequence(
      [
        iows(),
        expression_value(),
        filters(),
        iows()
      ],
      ast: fn [expression, filters] ->
        {:expression, expression, filters}
      end
    )
  end

  def parser(), do: get_parser("template_expression", fn -> expression() end)

  def parse(s) when is_binary(s) do
    case Ergo.parse(parser(), s) do
      %{status: :ok, ast: ast} ->
        {:ok, ast}

      %{status: {:error, errors}} ->
        {:error, errors}
    end
  end
end
