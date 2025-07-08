defmodule Rez.Parser.SchemaParser do
  @moduledoc """
  Defines the parsers that parse @schema elements with their special rules
  syntax.
  """
  import Ergo.Combinators
  import Ergo.Meta

  import Rez.Parser.UtilityParsers
  import Rez.Parser.ValueParsers
  import Rez.Parser.IdentifierParser
  # import Rez.Parser.AttributeParser
  import Rez.Parser.ParserTools

  alias Rez.Compiler.SchemaBuilder
  alias Ergo.Context

  alias Rez.AST.Schema

  def make_schema([elem_name, rules], position) do
    %Schema{
      element: elem_name,
      position: position,
      rules: rules |> List.flatten() |> Enum.sort(&(&1.priority < &2.priority))
    }
  end

  def make_schema([elem_name, first_rule, other_rules], position) do
    make_schema([elem_name, [first_rule | other_rules]], position)
  end

  # A @schema looks like:
  #  @schema <element_name> {
  #    attr_name: {rules}
  #  }
  def schema_directive() do
    sequence(
      [
        iliteral("@schema"),
        iws(),
        commit(),
        js_identifier("schema"),
        iws(),
        ignore(open_brace()),
        iws(),
        optional(schema_expression()),
        many(
          sequence([
            iws(),
            schema_expression()
          ])
        ),
        iws(),
        ignore(close_brace())
      ],
      label: "@schema",
      ctx: fn %Context{ast: ast} = ctx ->
        %{ctx | ast: make_schema(ast, resolve_position(ctx))}
      end
    )
  end

  defp schema_expression() do
    sequence(
      [
        js_identifier("attr"),
        ignore(colon()),
        iws(),
        commit(),
        ignore(open_brace()),
        iws(),
        optional(schema_rule()),
        many(
          sequence([
            iws(),
            ignore(comma()),
            iws(),
            schema_rule()
          ])
        ),
        iws(),
        ignore(close_brace())
      ],
      label: "schema-expression",
      ast: fn
        [attr_name, other_validations] ->
          SchemaBuilder.build(attr_name, [other_validations])

        [attr_name, first_validation, other_validations] ->
          SchemaBuilder.build(attr_name, List.flatten([first_validation | other_validations]))
      end
    )
  end

  defp schema_rule() do
    choice([
      # schema_default(),
      schema_validate_kind(),
      schema_validate_required(),
      schema_validate_allowed(),
      schema_validate_required_if(),
      schema_validate_requires(),
      schema_validate_xor(),
      schema_validate_or(),
      schema_validate_and(),
      schema_validate_min(),
      schema_validate_max(),
      schema_validate_ref_elem(),
      schema_validate_coll_kind(),
      schema_validate_min_length(),
      schema_validate_contains(),
      schema_validate_in(),
      # For assets
      schema_validate_existing_file(),
      # For functions
      schema_validate_params(),
      schema_validate_param_count(),
      # For items
      schema_validate_type_exists()
    ])
  end

  # defp schema_default() do
  #   sequence(
  #     [
  #       iliteral("default:"),
  #       iws(),
  #       attr_value()
  #     ],
  #     label: "default",
  #     ast: fn [value] ->
  #       {:default, value}
  #     end
  #   )
  # end

  defp schema_validate_kind() do
    sequence(
      [
        iliteral("kind:"),
        iws(),
        keywords()
      ],
      label: "validate-kind",
      ast: fn [kinds] ->
        {:kind, kinds}
      end
    )
  end

  defp schema_validate_required() do
    sequence(
      [
        iliteral("required:"),
        iws(),
        bool_value()
      ],
      label: "validate-required",
      ast: fn [is_required] ->
        {:required, is_required}
      end
    )
  end

  defp schema_validate_allowed() do
    sequence(
      [
        iliteral("allowed:"),
        iws(),
        bool_value()
      ],
      label: "validate-allowed",
      ast: fn [is_allowed] ->
        {:allowed, is_allowed}
      end
    )
  end

  defp schema_validate_required_if() do
    sequence(
      [
        iliteral("required_if:"),
        iws(),
        identifiers()
      ],
      label: "validate-required-if",
      ast: fn [attrs] ->
        {:required_if, attrs}
      end
    )
  end

  defp schema_validate_xor() do
    sequence(
      [
        iliteral("xor:"),
        iws(),
        identifiers()
      ],
      label: "validate-xor",
      ast: fn [attrs] ->
        {:xor, attrs}
      end
    )
  end

  defp schema_validate_or() do
    sequence(
      [
        iliteral("or:"),
        iws(),
        identifiers()
      ],
      label: "validate-or",
      ast: fn [attrs] ->
        {:or, attrs}
      end
    )
  end

  defp schema_validate_and() do
    sequence(
      [
        iliteral("and:"),
        iws(),
        identifiers()
      ],
      label: "validate-and",
      ast: fn [attrs] ->
        {:and, attrs}
      end
    )
  end

  defp schema_validate_requires() do
    sequence(
      [
        iliteral("requires:"),
        iws(),
        identifiers()
      ],
      label: "validate-requires",
      ast: fn [required_attrs] ->
        {:requires, required_attrs}
      end
    )
  end

  defp schema_validate_min() do
    sequence(
      [
        iliteral("min:"),
        iws(),
        number_value()
      ],
      label: "validate-min",
      ast: fn [{:number, min_value}] ->
        {:min_value, min_value}
      end
    )
  end

  defp schema_validate_max() do
    sequence(
      [
        iliteral("max:"),
        iws(),
        number_value()
      ],
      label: "validate-max",
      ast: fn [{:number, max_value}] ->
        {:max_value, max_value}
      end
    )
  end

  defp schema_validate_ref_elem() do
    sequence(
      [
        iliteral("ref_elem:"),
        iws(),
        elems()
      ],
      label: "validate-ref-elem",
      ast: fn [elems] ->
        {:ref_elem, elems}
      end
    )
  end

  defp schema_validate_coll_kind() do
    sequence(
      [
        iliteral("coll_kind:"),
        iws(),
        keywords()
      ],
      label: "validate-coll-kind",
      ast: fn [coll_kinds] ->
        {:coll_kind, coll_kinds}
      end
    )
  end

  defp schema_validate_min_length() do
    sequence(
      [
        iliteral("min_length:"),
        iws(),
        number_value()
      ],
      label: "validate-min-length",
      ast: fn [{:number, min_length}] ->
        {:min_length, min_length}
      end
    )
  end

  defp schema_validate_existing_file() do
    sequence(
      [
        iliteral("file_exists")
      ],
      label: "validate-existing-file",
      ast: fn [] ->
        :file_exists
      end
    )
  end

  defp schema_validate_params() do
    sequence(
      [
        iliteral("params:"),
        iws(),
        identifiers()
      ],
      label: "validate-params",
      ast: fn [params] ->
        {:params, params}
      end
    )
  end

  defp schema_validate_param_count() do
    sequence(
      [
        iliteral("param_count:"),
        iws(),
        number_value()
      ],
      label: "validate-param-count",
      ast: fn [{:number, count}] ->
        {:param_count, count}
      end
    )
  end

  defp schema_validate_contains() do
    sequence(
      [
        iliteral("contains:"),
        iws(),
        string_value()
      ],
      label: "validate-contains",
      ast: fn [{:dstring, sub_str}] ->
        {:contains, sub_str}
      end
    )
  end

  defp schema_validate_in() do
    sequence(
      [
        iliteral("in:"),
        iws(),
        values()
      ],
      label: "validate-in",
      ast: fn [values] ->
        {:in, values |> Enum.map(fn {_type, value} -> value end)}
      end
    )
  end

  defp schema_validate_type_exists() do
    sequence(
      [
        iliteral("type_exists")
      ],
      label: "validate-type-exists",
      ast: fn [] ->
        :type_exists
      end
    )
  end

  defp values() do
    sequence(
      [
        ignore(open_bracket()),
        iws(),
        value(),
        many(
          sequence([
            iws(),
            optional(
              sequence([
                ignore(comma()),
                iws()
              ])
            ),
            value()
          ])
        ),
        iws(),
        ignore(close_bracket())
      ],
      label: "values",
      ast: fn [first_value, other_values] ->
        [first_value | List.flatten(other_values)]
      end
    )
  end

  defp identifiers() do
    choice([
      js_identifier("attr") |> transform(fn attr -> [attr] end),
      identifier_list()
    ])
  end

  def identifier_list() do
    sequence(
      [
        ignore(open_bracket()),
        iws(),
        js_identifier("attr"),
        many(
          sequence([
            iws(),
            js_identifier("attr")
          ])
        ),
        iws(),
        ignore(close_bracket())
      ],
      label: "attr-list",
      ast: fn [first_attr, other_attrs] ->
        [first_attr | List.flatten(other_attrs)]
      end
    )
  end

  defp keywords() do
    choice(
      [
        keyword_value() |> transform(fn ast -> [ast] end),
        keyword_list()
      ],
      ast: fn ast ->
        Enum.map(ast, fn {:keyword, kw} -> String.to_atom(kw) end)
      end
    )
  end

  defp keyword_list() do
    sequence(
      [
        ignore(open_bracket()),
        iws(),
        keyword_value(),
        many(
          sequence([
            iws(),
            keyword_value()
          ])
        ),
        iws(),
        ignore(close_bracket())
      ],
      label: "keyword-list",
      ast: fn [first_kind, other_kinds] ->
        [first_kind | List.flatten(other_kinds)]
      end
    )
  end

  defp elems() do
    choice([
      elem() |> transform(fn ast -> [ast] end),
      elem_list()
    ])
  end

  defp elem() do
    sequence(
      [
        ignore(at()),
        js_identifier()
      ],
      label: "elem",
      ast: fn [elem] ->
        elem
      end
    )
  end

  defp elem_list() do
    sequence(
      [
        ignore(open_bracket()),
        iws(),
        elem(),
        many(sequence([iws(), elem()])),
        iws(),
        ignore(close_bracket())
      ],
      label: "elem-list",
      ast: fn [first_elem, other_elems] ->
        [first_elem | List.flatten(other_elems)]
      end
    )
  end
end
