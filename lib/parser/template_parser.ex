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
      iws: 0,
      iows: 0,
      colon: 0,
      comma: 0,
      open_brace: 0,
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
  def do_macro(), do: PC.get_parser("do_macro", fn -> literal("$do") end)
  def open_body(), do: PC.get_parser("open_body", fn -> literal("{%") end)
  def close_body(), do: PC.get_parser("close_body", fn -> literal("%}") end)
  def entails(), do: PC.get_parser("entails", fn -> literal("->") end)
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

  def conditional_expr() do
    sequence(
      [
        DP.text_delimited_by_nested_parsers(open_paren(), close_paren()),
        iows(),
        ignore(entails()),
        iows(),
        macro_body()
      ],
      ast: fn [expr, body] ->
        case TemplateParser.parse(body) do
          {:error, errors} ->
            IO.puts("Error compiling subtemplate for condition: #{inspect(expr)}")
            IO.puts(body)
            Enum.each(errors, fn error -> IO.inspect(error) end)
            {:error, "Cannot compile sub-template"}

          source_template ->
            if expr == "" do
              {"true", source_template}
            else
              {expr, source_template}
            end
        end
      end
    )
  end

  def conditional() do
    sequence(
      [
        ignore(if_macro()),
        commit(),
        iows(),
        conditional_expr(),
        many(
          sequence([
            iows(),
            conditional_expr()
          ])
        )
      ],
      ast: fn ast ->
        {:conditional, List.flatten(ast)}
      end
    )
  end

  import Rez.Parser.JSBindingParser, only: [binding_path: 0]

  def foreach() do
    sequence(
      [
        ignore(fe_macro()),
        ignore(open_paren()),
        iows(),
        js_identifier(),
        ignore(colon()),
        iws(),
        binding_path(),
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
        [iter_id, bound_path, content] ->
          {:foreach, iter_id, bound_path, TemplateParser.parse(content)}

        [iter_id, bound_path, content, [divider]] ->
          {:foreach, iter_id, bound_path, TemplateParser.parse(content),
           TemplateParser.parse(divider)}
      end
    )
  end

  def doblock() do
    sequence(
      [
        DP.text_delimited_by_prefix_and_nested_parsers(
          ignore(do_macro()),
          open_brace(),
          close_brace()
        )
      ],
      ast: fn [code] ->
        {:do, code}
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

  def la_open_conditional(),
    do:
      PC.get_parser("open_conditional", fn -> sequence([literal("$if"), iows(), literal("(")]) end)

  def la_open_doblock(), do: PC.get_parser("open_doblock", fn -> literal("$do{") end)
  def la_open_foreach(), do: PC.get_parser("open_foreach", fn -> literal("$foreach(") end)
  def escape_dollar(), do: PC.get_parser("escape_dollar", fn -> literal("\\$") end)

  def string() do
    char_parser =
      sequence([
        not_lookahead(
          choice([
            la_open_conditional(),
            la_open_doblock(),
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
        conditional(),
        doblock(),
        interpolation(),
        foreach(),
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
