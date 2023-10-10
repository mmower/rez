defmodule Rez.Parser.TemplateParser do
  import Ergo.Terminals, only: [literal: 1, any: 0]

  import Ergo.Combinators,
    only: [
      ignore: 1,
      choice: 1,
      sequence: 1,
      sequence: 2,
      optional: 1,
      many: 1,
      many: 2,
      replace: 2,
      not_lookahead: 1
    ]

  import Ergo.Meta, only: [commit: 0]

  import Rez.Parser.UtilityParsers,
    only: [
      dot: 0,
      iws: 0,
      iows: 0,
      colon: 0,
      comma: 0,
      close_brace: 0,
      open_paren: 0,
      close_paren: 0
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  alias Rez.Parser.TemplateParser
  alias Rez.Parser.DelimitedParser, as: DP
  alias Rez.Parser.TemplateExpressionParser, as: TEP
  alias Rez.Parser.ParserCache, as: PC

  def if_macro(), do: PC.get_parser("if_macro", fn -> literal("$if") end)
  def fe_macro(), do: PC.get_parser("fe_macro", fn -> literal("$foreach") end)
  def open_body(), do: PC.get_parser("open_body", fn -> literal("{%") end)
  def close_body(), do: PC.get_parser("close_body", fn -> literal("%}") end)
  def open_interpolation(), do: PC.get_parser("open_interpolation", fn -> literal("${") end)

  def cancel_interpolation_marker() do
    literal("\\$") |> replace("$")
  end

  def macro_body() do
    DP.text_delimited_by_nested_parsers(
      open_body(),
      close_body()
    )
  end

  def conditional() do
    sequence(
      [
        DP.text_delimited_by_prefix_and_nested_parsers(
          ignore(if_macro()),
          open_paren(),
          close_paren()
        ),
        iows(),
        macro_body(),
        optional(
          sequence([
            iows(),
            ignore(comma()),
            iows(),
            macro_body()
          ])
        )
      ],
      ast: fn
        [[expr], true_content] ->
          {:conditional, expr, TemplateParser.parse(true_content)}

        [[expr], true_content, [false_content]] ->
          {:conditional, expr, TemplateParser.parse(true_content),
           TemplateParser.parse(false_content)}
      end
    )
  end

  def foreach() do
    sequence(
      [
        ignore(fe_macro()),
        ignore(open_paren()),
        iows(),
        js_identifier(),
        ignore(colon()),
        iws(),
        choice([
          sequence([js_identifier(), ignore(dot()), js_identifier()],
            ast: fn [binding_id, property_name] -> {binding_id, property_name} end
          ),
          sequence([js_identifier()], ast: fn [binding_id] -> {binding_id, nil} end)
        ]),
        iows(),
        ignore(close_paren()),
        iows(),
        macro_body(),
        optional(
          sequence([
            iows(),
            ignore(comma()),
            iows(),
            macro_body()
          ])
        )
      ],
      ast: fn
        [iter_id, binding_spec, content] ->
          {:foreach, iter_id, binding_spec, TemplateParser.parse(content)}

        [iter_id, binding_spec, content, [divider]] ->
          {:foreach, iter_id, binding_spec, TemplateParser.parse(content),
           TemplateParser.parse(divider)}
      end
    )
  end

  def interpolation() do
    sequence(
      [
        ignore(open_interpolation()),
        commit(),
        many(
          sequence([
            not_lookahead(close_brace()),
            any()
          ]),
          ast: fn ast -> List.to_string(ast) |> String.trim() end
        ),
        ignore(close_brace())
      ],
      ast: fn [expr | _] ->
        case TEP.parse(expr) do
          {:ok, ex} ->
            {:interpolate, ex}

          error ->
            error
        end
      end
    )
  end

  def open_helper(), do: PC.get_parser("open_helper", fn -> literal("{{") end)
  def close_helper(), do: PC.get_parser("close_helper", fn -> literal("}}") end)

  def helper() do
    sequence([
      ignore(open_helper()),
      commit(),
      many(
        sequence([
          not_lookahead(close_helper()),
          any()
        ])
      ),
      ignore(close_helper())
    ])
  end

  def la_open_conditional(), do: PC.get_parser("open_conditional", fn -> literal("$if(") end)
  def la_open_foreach(), do: PC.get_parser("open_foreach", fn -> literal("$foreach(") end)
  def escape_dollar(), do: PC.get_parser("escape_dollar", fn -> literal("\\$") end)

  def string() do
    char_parser =
      sequence([
        not_lookahead(
          choice([
            la_open_conditional(),
            open_interpolation(),
            la_open_foreach(),
            escape_dollar()
          ])
        ),
        any()
      ])

    sequence(
      [
        char_parser,
        many(char_parser)
      ],
      ast: fn ast -> ast |> List.flatten() |> List.to_string() end
    )
  end

  def template_parser() do
    many(
      choice([
        cancel_interpolation_marker(),
        interpolation(),
        conditional(),
        foreach(),
        helper(),
        string()
      ]),
      ast: fn ast -> {:source_template, ast} end
    )
  end

  def parse(s) do
    parser = PC.get_parser("template_parser", fn -> template_parser() end)

    case Ergo.parse(parser, s) do
      %{status: :ok, ast: ast} ->
        ast

      %{status: {:fatal, error}} ->
        {:error, error}

      %{status: {:error, error}} ->
        {:error, error}
    end
  end
end
