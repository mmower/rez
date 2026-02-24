defmodule Rez.Parser.TemplateParser do
  @moduledoc """
  Defines the parsers that parses source_template strings into the structure
  used to build them at runtime. Returns a {:source_template, ast}
  """
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
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  def if_macro(), do: cached_parser(literal("$if"))
  def fe_macro(), do: cached_parser(literal("$foreach"))
  def ps_macro(), do: cached_parser(literal("$partial"))
  def do_macro(), do: cached_parser(literal("$do"))
  def break_macro(), do: cached_parser(literal("$break"))
  def open_body(), do: cached_parser(literal("{%"))
  def close_body(), do: cached_parser(literal("%}"))
  def entails(), do: cached_parser(literal("->"))
  def open_interpolation(), do: cached_parser(literal("${"))

  def open_user_component(),
    do:
      cached_parser(
        sequence([
          left_angle_bracket(),
          dot(),
          js_identifier()
        ])
      )

  def cancel_interpolation_marker() do
    cached_parser(literal("\\$") |> replace("$"))
  end

  def macro_body() do
    cached_parser(
      DP.text_delimited_by_nested_parsers(
        open_body(),
        close_body()
      )
    )
  end

  def conditional_expr() do
    cached_parser(
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
              {:error, format_sub_template_errors("$if(#{expr}) -> {% ... %}", errors)}

            source_template ->
              if expr == "" do
                {"true", source_template}
              else
                {expr, source_template}
              end
          end
        end
      )
    )
  end

  def conditional() do
    cached_parser(
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
    )
  end

  import Rez.Parser.JSBindingParser, only: [binding_path: 0]

  def foreach() do
    cached_parser(
      sequence(
        [
          ignore(fe_macro()),
          commit(),
          iows(),
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
            case TemplateParser.parse(content) do
              {:error, errors} ->
                {:error, format_sub_template_errors("$foreach(#{iter_id}: ...) body", errors)}

              parsed_content ->
                {:foreach, iter_id, bound_path, parsed_content}
            end

          [iter_id, bound_path, content, [divider]] ->
            with {:ok, parsed_content} <-
                   wrap_parse_result(
                     TemplateParser.parse(content),
                     "$foreach(#{iter_id}: ...) body"
                   ),
                 {:ok, parsed_divider} <-
                   wrap_parse_result(
                     TemplateParser.parse(divider),
                     "$foreach(#{iter_id}: ...) divider"
                   ) do
              {:foreach, iter_id, bound_path, parsed_content, parsed_divider}
            end
        end
      )
    )
  end

  def partial_param_value() do
    cached_parser(
      choice([
        string_value(),
        number_value(),
        bool_value(),
        binding_path()
      ])
    )
  end

  def partial_param() do
    cached_parser(
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
    )
  end

  def partial_params() do
    cached_parser(
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
    )
  end

  def partial() do
    cached_parser(
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
    )
  end

  def doblock() do
    cached_parser(
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
    )
  end

  def breakblock() do
    cached_parser(
      DP.text_delimited_by_prefix_and_nested_parsers(
        ignore(break_macro()),
        open_brace(),
        close_brace()
      )
      |> transform(fn [code] ->
        {:break, code}
      end)
    )
  end

  def interpolation() do
    cached_parser(
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
    )
  end

  alias Ergo.Parser
  alias Ergo.Context

  def debug_captures() do
    cached_parser(
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
    )
  end

  def open_container_user_component() do
    cached_parser(
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
    )
  end

  def open_nested_container_user_component() do
    cached_parser(
      sequence([
        left_angle_bracket(),
        dot(),
        captured_literal(:macro_tag),
        optional(many(user_component_attr())),
        iows(),
        right_angle_bracket()
      ])
    )
  end

  def close_container_user_component() do
    cached_parser(
      sequence([
        ignore(left_angle_bracket()),
        ignore(forward_slash()),
        ignore(dot()),
        ignore(captured_literal(:macro_tag)),
        ignore(right_angle_bracket())
      ])
    )
  end

  def container_user_component() do
    cached_parser(
      sequence(
        [
          open_container_user_component(),
          DP.text_delimited_by_nested_parsers(
            open_nested_container_user_component(),
            close_container_user_component(),
            start_open: true,
            invalid_pattern: &invalid_component_close/0
          )
        ],
        ast: fn [[tag_name, attrs], content] ->
          case TemplateParser.parse(content) do
            {:error, errors} ->
              {:error, format_sub_template_errors("<.#{tag_name}> content", errors)}

            parsed_content ->
              {:user_component, tag_name, attrs, parsed_content}
          end
        end
      )
    )
  end

  def self_contained_user_component() do
    cached_parser(
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

  def invalid_component_close() do
    cached_parser(
      sequence(
        [
          ignore(left_angle_bracket()),
          ignore(dot()),
          ignore(forward_slash()),
          js_identifier(),
          ignore(right_angle_bracket())
        ],
        ctx: fn %Context{ast: [tag_name]} = ctx ->
          ctx
          |> Context.add_error(
            :invalid_close_tag,
            "Invalid component close tag <./#{tag_name}>. Did you mean </.#{tag_name}>?"
          )
          |> Context.make_error_fatal()
        end
      )
    )
  end

  def user_component() do
    cached_parser(
      choice([
        self_contained_user_component(),
        container_user_component()
      ])
    )
  end

  def la_open_conditional(),
    do: cached_parser(sequence([literal("$if"), iows(), literal("(")]))

  def la_open_doblock(), do: cached_parser(literal("$do{"))
  def la_open_breakblock(), do: cached_parser(literal("$break{"))

  def la_open_foreach(),
    do: cached_parser(sequence([literal("$foreach"), iows(), literal("(")]))

  def la_open_partial(), do: cached_parser(literal("$partial("))
  def escape_dollar(), do: cached_parser(literal("\\$"))

  def string() do
    char_parser =
      sequence([
        not_lookahead(
          choice([
            la_open_conditional(),
            la_open_doblock(),
            la_open_breakblock(),
            open_interpolation(),
            la_open_foreach(),
            la_open_partial(),
            open_user_component(),
            escape_dollar()
          ])
        ),
        any()
      ])

    cached_parser(
      sequence(
        [
          char_parser,
          many(char_parser)
        ],
        ast: fn ast ->
          ast |> List.flatten() |> List.to_string()
        end
      )
    )
  end

  def template_parser() do
    cached_parser(
      many(
        choice([
          cancel_interpolation_marker(),
          conditional(),
          doblock(),
          breakblock(),
          interpolation(),
          foreach(),
          partial(),
          user_component(),
          string()
        ]),
        ast: fn ast -> {:source_template, ast} end
      )
    )
  end

  def parse(s) do
    parser = cached_parser(template_parser())

    case Ergo.parse(parser, s) do
      %{status: :ok, ast: ast} ->
        ast

      %{status: {:fatal, error}} ->
        {:error, error}

      %{status: {:error, error}} ->
        {:error, error}
    end
  end

  defp wrap_parse_result({:error, errors}, context) do
    {:error, format_sub_template_errors(context, errors)}
  end

  defp wrap_parse_result(parsed, _context), do: {:ok, parsed}

  defp format_sub_template_errors(context, errors) when is_list(errors) do
    error_details =
      Enum.map_join(errors, "; ", fn
        {error_type, {line, col}, message} ->
          "#{error_type} at line #{line}, col #{col}: #{message}"

        other ->
          inspect(other)
      end)

    "Error in #{context}: #{error_details}"
  end

  defp format_sub_template_errors(context, error) when is_binary(error) do
    "Error in #{context}: #{error}"
  end

  defp format_sub_template_errors(context, error) do
    "Error in #{context}: #{inspect(error)}"
  end
end
