defmodule Rez.Parser.TemplateParser do
  import Ergo.Terminals, only: [char: 1, literal: 1, any: 0]

  import Ergo.Combinators,
    only: [
      ignore: 1,
      choice: 1,
      sequence: 1,
      sequence: 2,
      many: 1,
      many: 2,
      replace: 2,
      not_lookahead: 1
    ]

  import Ergo.Meta, only: [commit: 0]

  import Rez.Parser.UtilityParsers, only: [iows: 0]

  alias Rez.Parser.DelimitedParser, as: DP
  alias Rez.Parser.TemplateExpressionParser, as: TEP
  alias Rez.Parser.ParserCache, as: PC

  def forward_slash(), do: char(?\\)
  def dollar(), do: char(?$)
  def open_brace(), do: char(?{)
  def close_brace(), do: char(?})

  def cancel_interpolation_marker() do
    literal("\\$") |> replace("$")
  end

  def conditional() do
    sequence(
      [
        DP.text_delimited_by_prefix_and_nested_parsers(
          ignore(literal("$if")),
          char(?{),
          char(?})
        ),
        iows(),
        DP.text_delimited_by_nested_parsers(
          literal("{%"),
          literal("%}")
        )
      ],
      ast: fn [[expr], content] ->
        {:conditional, expr, content}
      end
    )
  end

  def interpolation() do
    sequence(
      [
        ignore(literal("${")),
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

  def string() do
    char_parser =
      sequence([
        not_lookahead(
          choice([
            literal("$if{"),
            literal("${"),
            literal("\\$")
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
        helper(),
        string()
      ]),
      ast: fn ast -> {:template, ast} end
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
