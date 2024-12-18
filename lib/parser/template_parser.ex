defmodule Rez.Parser.TemplateParser do
  import Ergo.Terminals, only: [literal: 1, any: 0, captured_literal: 1]

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
      not_lookahead: 1,
      transform: 2
    ]

  import Ergo.Meta, only: [commit: 0, capture: 2]

  import Rez.Parser.ValueParsers,
    only: [
      string_value: 0,
      number_value: 0,
      bool_value: 0,
      elem_ref_value: 0
    ]

  import Rez.Parser.JSBindingParser, only: [binding_path: 0]

  import Rez.Parser.UtilityParsers,
    only: [
      dot: 0,
      iws: 0,
      iows: 0,
      colon: 0,
      comma: 0,
      equals: 0,
      open_brace: 0,
      close_brace: 0,
      open_paren: 0,
      close_paren: 0,
      forward_slash: 0,
      left_angle_bracket: 0,
      right_angle_bracket: 0
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  alias Rez.Parser.TemplateParser
  alias Rez.Parser.DelimitedParser, as: DP
  alias Rez.Parser.TemplateExpressionParser, as: TEP
  alias Rez.Parser.ParserCache, as: PC

  def if_macro(), do: PC.get_parser("if_macro", fn -> literal("$if") end)
  def fe_macro(), do: PC.get_parser("fe_macro", fn -> literal("$foreach") end)
  def ps_macro(), do: PC.get_parser("ps_macro", fn -> literal("$partial") end)
  def do_macro(), do: PC.get_parser("do_macro", fn -> literal("$do") end)
  def open_body(), do: PC.get_parser("open_body", fn -> literal("{%") end)
  def close_body(), do: PC.get_parser("close_body", fn -> literal("%}") end)
  def entails(), do: PC.get_parser("entails", fn -> literal("->") end)
  def open_interpolation(), do: PC.get_parser("open_interpolation", fn -> literal("${") end)

  def open_user_component(),
    do:
      PC.get_parser("user_component", fn ->
        sequence([
          left_angle_bracket(),
          dot(),
          js_identifier()
        ])
      end)

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

  def partial_param_value() do
    choice([
      string_value(),
      number_value(),
      bool_value(),
      binding_path()
    ])
  end

  def partial_param() do
    sequence(
      [
        iows(),
        ignore(optional(comma())),
        iows(),
        js_identifier(),
        iows(),
        ignore(colon()),
        iows(),
        partial_param_value()
      ],
      ast: fn [param_id, param_value] ->
        {:param, param_id, param_value}
      end
    )
  end

  def partial_params() do
    sequence(
      [
        ignore(open_brace()),
        many(partial_param()),
        ignore(close_brace())
      ],
      ast: fn [params] ->
        {
          :params,
          Enum.reduce(params, %{}, fn {:param, param_id, param_value}, params ->
            Map.put(params, param_id, param_value)
          end)
        }
      end
    )
  end

  def partial() do
    sequence(
      [
        ignore(ps_macro()),
        ignore(open_paren()),
        iows(),
        choice([
          string_value(),
          elem_ref_value(),
          binding_path(),
          js_identifier()
        ]),
        iows(),
        ignore(comma()),
        iows(),
        partial_params(),
        iows(),
        ignore(close_paren())
      ],
      ast: fn [partial_expr, param_map] ->
        {:partial, partial_expr, param_map}
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

  alias Ergo.Parser
  alias Ergo.Context

  def debug_captures() do
    Parser.terminal(
      :debug_capture,
      "debug_capture",
      fn %Context{} = ctx ->
        IO.puts("DEBUG CAPTURES")

        ctx
        |> Map.get(:captures, %{})
        |> IO.inspect()

        ctx
      end
    )
  end

  def open_container_user_component() do
    sequence(
      [
        ignore(left_angle_bracket()),
        ignore(dot()),
        js_identifier() |> capture(:macro_tag),
        optional(many(user_component_attr())),
        iows(),
        ignore(right_angle_bracket())
      ],
      ast: fn
        [tag_name] ->
          [tag_name, []]

        [_tag_name, _attrs] = ast ->
          ast
      end
    )
  end

  def open_nested_container_user_component() do
    sequence([
      left_angle_bracket(),
      dot(),
      captured_literal(:macro_tag),
      optional(many(user_component_attr())),
      iows(),
      right_angle_bracket()
    ])
  end

  def close_container_user_component() do
    sequence([
      ignore(left_angle_bracket()),
      ignore(forward_slash()),
      ignore(dot()),
      ignore(captured_literal(:macro_tag)),
      ignore(right_angle_bracket())
    ])
  end

  def container_user_component() do
    sequence(
      [
        open_container_user_component(),
        DP.text_delimited_by_nested_parsers(
          open_nested_container_user_component(),
          close_container_user_component(),
          start_open: true
        )
      ],
      ast: fn [[tag_name, attrs], content] ->
        {:user_component, tag_name, attrs, TemplateParser.parse(content)}
      end
    )
  end

  def self_contained_user_component() do
    sequence(
      [
        ignore(left_angle_bracket()),
        ignore(dot()),
        js_identifier(),
        optional(many(user_component_attr())),
        iows(),
        ignore(forward_slash()),
        ignore(right_angle_bracket())
      ],
      ast: fn
        [name] ->
          {:user_component, name, %{}, nil}

        [name, attributes] ->
          {:user_component, name, Enum.into(attributes, %{}), nil}
      end
    )
  end

  defp dynamic_attr_value() do
    DP.text_delimited_by_nested_parsers(open_brace(), close_brace())
    |> transform(fn expr -> {:attr_expr, expr} end)
  end

  defp user_component_attr() do
    sequence(
      [
        iws(),
        js_identifier(),
        ignore(equals()),
        choice([
          number_value(),
          dynamic_attr_value(),
          string_value()
        ])
      ],
      ast: fn [attr_name, attr_value] ->
        {attr_name, attr_value}
      end
    )
  end

  def user_component() do
    choice([
      self_contained_user_component(),
      container_user_component()
    ])
  end

  def la_open_conditional(),
    do:
      PC.get_parser("open_conditional", fn -> sequence([literal("$if"), iows(), literal("(")]) end)

  def la_open_doblock(), do: PC.get_parser("open_doblock", fn -> literal("$do{") end)
  def la_open_foreach(), do: PC.get_parser("open_foreach", fn -> literal("$foreach(") end)
  def la_open_partial(), do: PC.get_parser("open_partial", fn -> literal("$partial(") end)
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
            la_open_partial(),
            open_user_component(),
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
      ast: fn ast ->
        ast |> List.flatten() |> List.to_string()
      end
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
        partial(),
        user_component(),
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
