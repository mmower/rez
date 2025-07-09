defmodule Rez.Parser.CollectionParser do
  @moduledoc """
  Defines the parsers that parse collection values
  * binding_list
  * list
  * set
  * probability_table
  """
  alias Rez.Parser.ParserCache

  import Ergo.Combinators,
    only: [
      choice: 1,
      choice: 2,
      ignore: 1,
      lazy: 1,
      many: 1,
      optional: 1,
      sequence: 1,
      sequence: 2
      # transform: 2,
      # replace: 2
    ]

  # import Ergo.Meta, only: [commit: 0]

  import Rez.Parser.UtilityParsers,
    only: [
      iows: 0,
      iws: 0,
      colon: 0,
      hash: 0,
      comma: 0,
      pipe: 0,
      star: 0,
      # plus: 0,
      open_brace: 0,
      close_brace: 0,
      open_bracket: 0,
      close_bracket: 0
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  import Rez.Parser.ValueParsers,
    only: [
      value: 0,
      elem_ref_value: 0,
      code_block_value: 0,
      function_value: 0,
      string_value: 0,
      number_value: 0,
      bool_value: 0
    ]

  import Rez.Parser.JSBindingParser

  # import Rez.Parser.DefaultParser

  def collection_value() do
    ParserCache.get_parser("collection_value", fn ->
      choice([
        value(),
        collection()
      ])
    end)
  end

  # Set

  def set() do
    ParserCache.get_parser("set", fn ->
      sequence(
        [
          ignore(hash()),
          ignore(open_brace()),
          iows(),
          optional(
            sequence([
              collection_value(),
              many(
                sequence([
                  iws(),
                  collection_value()
                ])
              )
            ])
          ),
          iows(),
          ignore(close_brace())
        ],
        label: "set-value",
        debug: true,
        ast: fn set -> {:set, MapSet.new(List.flatten(set))} end
      )
    end)
  end

  # Binding

  # Bindings are a special kind of list value
  # They are formed of a prefix: value but only support specific kinds of
  # value that are used for value binding

  def bound_literal() do
    ParserCache.get_parser("bound_literal", fn ->
      choice(
        [
          string_value(),
          number_value(),
          bool_value()
        ],
        label: "bound-literal",
        ast: fn value ->
          {:literal, value}
        end
      )
    end)
  end

  def bound_source() do
    ParserCache.get_parser("bound_source", fn ->
      sequence(
        [
          optional(star()),
          choice([
            elem_ref_value(),
            binding_path(),
            code_block_value(),
            function_value()
          ])
        ],
        label: "bound-source",
        ast: fn
          [source] ->
            {:source, false, source}

          [_star, source] ->
            {:source, true, source}
        end
      )
    end)
  end

  # Lists

  def list() do
    ParserCache.get_parser("list", fn ->
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          optional(
            sequence([
              collection_value(),
              many(
                sequence([
                  iws(),
                  ignore(optional(sequence([comma(), iws()]))),
                  collection_value()
                ])
              )
            ])
          ),
          iows(),
          ignore(close_bracket())
        ],
        label: "list-value",
        debug: true,
        ast: fn list -> {:list, List.flatten(list)} end
      )
    end)
  end

  def list_binding() do
    ParserCache.get_parser("list_binding", fn ->
      sequence(
        [
          js_identifier(),
          ignore(colon()),
          iws(),
          choice([
            bound_literal(),
            bound_source()
          ])
        ],
        ast: fn [prefix, literal_or_source] ->
          {:list_binding, {prefix, literal_or_source}}
        end
      )
    end)
  end

  def binding_list() do
    ParserCache.get_parser("binding_list", fn ->
      sequence(
        [
          ignore(open_bracket()),
          many(
            sequence([
              iows(),
              ignore(
                optional(
                  sequence([
                    comma(),
                    iows()
                  ])
                )
              ),
              list_binding()
            ])
          ),
          iows(),
          ignore(close_bracket())
        ],
        ast: fn ast -> {:list, List.flatten(ast)} end
      )
    end)
  end

  # Probability Table

  def probability_table() do
    ParserCache.get_parser("probability_table", fn ->
      sequence(
        [
          ignore(pipe()),
          many(
            sequence([
              iows(),
              value(),
              iws(),
              Ergo.Numeric.uint()
            ])
          ),
          ignore(pipe())
        ],
        ast: fn ast ->
          {:ptable,
           ast
           |> List.flatten(ast)
           |> Enum.chunk_every(2, 2, :discard)
           |> Enum.map(fn [a, b] -> {a, b} end)}
        end
      )
    end)
  end

  # Table

  # def table_attribute() do
  #   ParserCache.get_parser("table_attribute", fn ->
  #     sequence(
  #       [
  #         choice([
  #           js_identifier(),
  #           string_value() |> transform(fn {:string, id} -> id end)
  #         ]),
  #         ignore(colon()),
  #         iws(),
  #         commit(),
  #         collection_value()
  #       ],
  #       label: "attribute",
  #       debug: true,
  #       ast: fn [id, {type, value}] ->
  #         %Rez.AST.Attribute{name: id, type: type, value: value}
  #       end
  #     )
  #   end)
  # end

  # def table() do
  #   ParserCache.get_parser("table", fn ->
  #     sequence(
  #       [
  #         ignore(open_brace()),
  #         iows(),
  #         optional(
  #           many(
  #             sequence(
  #               [
  #                 iows(),
  #                 table_attribute()
  #               ],
  #               ast: fn [attribute] -> attribute end
  #             )
  #           )
  #         ),
  #         iows(),
  #         ignore(close_brace())
  #       ],
  #       label: "table-value",
  #       debug: true,
  #       ast: fn [ast] ->
  #         Enum.reduce(ast, %{}, fn %Rez.AST.Attribute{name: name} = attr, table ->
  #           Map.put(table, name, attr)
  #         end)
  #       end
  #     )
  #     |> transform(fn table -> {:table, table} end)
  #   end)
  # end

  # Collection

  def collection() do
    ParserCache.get_parser("collection", fn ->
      choice([
        lazy(binding_list()),
        lazy(list()),
        lazy(set()),
        # lazy(table()),
        probability_table()
      ])
    end)
  end
end
