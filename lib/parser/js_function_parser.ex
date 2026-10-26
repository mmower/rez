defmodule Rez.Parser.JSFunctionParser do
  @moduledoc """
  Parses JavaScript function expressions with support for destructuring
  parameters and default values.

  Supports:
  - Simple identifiers: `function(x, y) {...}`
  - Object destructuring: `function({x, y}) {...}`
  - Array destructuring: `function([a, b]) {...}`
  - Default values (literals only): `function(x = 0) {...}`
  - Rest parameters: `function(...args) {...}`
  - Combinations: `function(x, {y, z} = {}, ...rest) {...}`
  - Arrow functions: `(x, y) => {...}`

  Each parameter is rendered to its JS string form during parsing.
  The produced AST is `{:function, {:std | :arrow, param_list, body}}`
  where `param_list` is a list of strings.
  """

  import Ergo.Combinators
  import Ergo.Terminals
  import Ergo.Numeric

  import Rez.Parser.ParserCache, only: [cached_parser: 1]
  import Rez.Parser.IdentifierParser
  import Rez.Parser.JSBlockParser, only: [js_block: 2]
  import Rez.Parser.UtilityParsers

  # ---------------------------------------------------------------------------
  # Literal parsers (for default values)
  # ---------------------------------------------------------------------------

  def js_number_literal() do
    cached_parser(
      choice([
        sequence(
          [
            char(?-),
            number()
          ],
          ast: fn [?-, n] -> "-#{n}" end
        ),
        number() |> transform(fn n -> to_string(n) end)
      ])
    )
  end

  def js_string_literal() do
    cached_parser(
      choice([
        js_double_quoted_string_literal(),
        js_single_quoted_string_literal()
      ])
    )
  end

  defp js_double_quoted_string_literal() do
    sequence(
      [
        ignore(char(?\")),
        many(
          choice([
            sequence([char(?\\), any()], ast: fn [?\\, c] -> [?\\, c] end),
            not_char([?\", ?\\])
          ])
        ),
        ignore(char(?\"))
      ],
      ast: fn [chars] ->
        inner = chars |> List.flatten() |> List.to_string()
        "\"#{inner}\""
      end
    )
  end

  defp js_single_quoted_string_literal() do
    sequence(
      [
        ignore(char(?')),
        many(
          choice([
            sequence([char(?\\), any()], ast: fn [?\\, c] -> [?\\, c] end),
            not_char([?', ?\\])
          ])
        ),
        ignore(char(?'))
      ],
      ast: fn [chars] ->
        inner = chars |> List.flatten() |> List.to_string()
        "'#{inner}'"
      end
    )
  end

  def js_bool_literal() do
    cached_parser(
      choice([
        literal("true") |> transform(fn _ -> "true" end),
        literal("false") |> transform(fn _ -> "false" end)
      ])
    )
  end

  def js_null_literal() do
    cached_parser(literal("null") |> transform(fn _ -> "null" end))
  end

  def js_undefined_literal() do
    cached_parser(literal("undefined") |> transform(fn _ -> "undefined" end))
  end

  def js_array_literal() do
    cached_parser(js_block(?[, ?]))
  end

  def js_object_literal() do
    cached_parser(js_block(?{, ?}))
  end

  def js_literal() do
    cached_parser(
      choice([
        js_string_literal(),
        js_bool_literal(),
        js_null_literal(),
        js_undefined_literal(),
        js_array_literal(),
        js_object_literal(),
        js_number_literal()
      ])
    )
  end

  # ---------------------------------------------------------------------------
  # Shared pieces
  #
  # The grammar is left-factored: wherever two alternatives share a prefix
  # (e.g. `key: target = literal` vs `key: target`) the prefix is parsed once
  # and the differing suffix is optional. Ergo's choice/2 does not memoise, so
  # trying the longer alternative first re-parses the prefix on failure, and
  # with nested patterns that cost doubles at each level of nesting.
  # ---------------------------------------------------------------------------

  def js_rest_param() do
    cached_parser(
      sequence(
        [
          ignore(literal("...")),
          js_identifier()
        ],
        ast: fn [name] -> "...#{name}" end
      )
    )
  end

  def js_default_value() do
    cached_parser(
      optional(
        sequence(
          [
            iows(),
            ignore(char(?=)),
            iows(),
            js_literal()
          ],
          ast: fn [default_val] -> default_val end
        )
      )
    )
  end

  # Not cached: called with different target parsers from cached call sites.
  defp with_default(target_parser) do
    sequence(
      [
        target_parser,
        js_default_value()
      ],
      ast: fn
        [target] -> target
        [target, default_val] -> "#{target} = #{default_val}"
      end
    )
  end

  # ---------------------------------------------------------------------------
  # Object pattern elements (inside {})
  # ---------------------------------------------------------------------------

  # `key` or `key: target`
  def js_obj_key_target() do
    cached_parser(
      sequence(
        [
          js_identifier(),
          optional(
            sequence(
              [
                iows(),
                ignore(char(?:)),
                iows(),
                lazy(js_binding_target())
              ],
              ast: fn [target] -> target end
            )
          )
        ],
        ast: fn
          [key] -> key
          [key, target] -> "#{key}: #{target}"
        end
      )
    )
  end

  # `...rest`, `key`, `key = literal`, `key: target`, `key: target = literal`
  def js_obj_elem() do
    cached_parser(
      choice(
        [
          js_rest_param(),
          with_default(js_obj_key_target())
        ],
        label: "js-object-pattern-element"
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Array pattern elements (inside [])
  # ---------------------------------------------------------------------------

  # `...rest`, `target`, `target = literal`
  def js_arr_elem() do
    cached_parser(
      choice(
        [
          js_rest_param(),
          with_default(lazy(js_binding_target()))
        ],
        label: "js-array-pattern-element"
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Pattern parsers
  # ---------------------------------------------------------------------------

  def js_object_pattern() do
    cached_parser(
      sequence(
        [
          ignore(char(?{)),
          iows(),
          js_obj_elem(),
          many(
            sequence(
              [
                iows(),
                ignore(char(?,)),
                iows(),
                js_obj_elem()
              ],
              ast: fn [elem] -> elem end
            )
          ),
          iows(),
          ignore(char(?}))
        ],
        label: "js-object-pattern",
        ast: fn [first | [rest]] ->
          elems = [first | rest]
          "{#{Enum.join(elems, ", ")}}"
        end
      )
    )
  end

  def js_array_pattern() do
    cached_parser(
      sequence(
        [
          ignore(char(?[)),
          iows(),
          js_arr_elem(),
          many(
            sequence(
              [
                iows(),
                ignore(char(?,)),
                iows(),
                js_arr_elem()
              ],
              ast: fn [elem] -> elem end
            )
          ),
          iows(),
          ignore(char(?]))
        ],
        label: "js-array-pattern",
        ast: fn [first | [rest]] ->
          elems = [first | rest]
          "[#{Enum.join(elems, ", ")}]"
        end
      )
    )
  end

  def js_binding_target() do
    cached_parser(
      choice(
        [
          js_object_pattern(),
          js_array_pattern(),
          js_identifier()
        ],
        label: "js-binding-target"
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Parameter parsers
  # ---------------------------------------------------------------------------

  # `...rest`, `target`, `target = literal`
  def js_param() do
    cached_parser(
      choice(
        [
          js_rest_param(),
          with_default(js_binding_target())
        ],
        label: "js-param"
      )
    )
  end

  def js_param_list() do
    cached_parser(
      sequence(
        [
          js_param(),
          many(
            sequence(
              [
                iows(),
                ignore(char(?,)),
                iows(),
                js_param()
              ],
              ast: fn [param] -> param end
            )
          )
        ],
        ast: fn [first | [rest]] ->
          [first | rest]
        end
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Function parsers
  # ---------------------------------------------------------------------------

  def js_traditional_function() do
    cached_parser(
      sequence(
        [
          ignore(literal("function")),
          iows(),
          ignore(char(?()),
          iows(),
          optional(js_param_list()),
          iows(),
          ignore(char(?))),
          iows(),
          js_block(?{, ?})
        ],
        label: "js-traditional-function",
        ast: fn
          [params, body] when is_list(params) ->
            {:function, {:std, params, body}}

          [body] ->
            {:function, {:std, [], body}}
        end
      )
    )
  end

  def js_arrow_function() do
    cached_parser(
      sequence(
        [
          ignore(char(?()),
          iows(),
          optional(js_param_list()),
          iows(),
          ignore(char(?))),
          iows(),
          ignore(literal("=>")),
          iows(),
          js_block(?{, ?})
        ],
        label: "js-arrow-function",
        ast: fn
          [params, body] when is_list(params) ->
            {:function, {:arrow, params, body}}

          [body] ->
            {:function, {:arrow, [], body}}
        end
      )
    )
  end

  def js_function() do
    cached_parser(
      choice([
        js_traditional_function(),
        js_arrow_function()
      ])
    )
  end

  def js_append_function() do
    cached_parser(
      sequence(
        [ignore(char(?+)), js_function()],
        label: "js-append-function",
        ast: fn [{:function, f}] -> {:append_function, f} end
      )
    )
  end
end
