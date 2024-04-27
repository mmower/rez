defmodule Rez.Parser.CollectionParser do
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
      sequence: 2,
      transform: 2
    ]

  import Ergo.Meta, only: [commit: 0]

  import Rez.Parser.UtilityParsers,
    only: [
      iows: 0,
      iws: 0,
      colon: 0,
      hash: 0,
      comma: 0,
      pipe: 0,
      star: 0,
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
      function_value: 0
    ]

  import Rez.Parser.JSBindingParser

  def collection_value() do
    choice([
      collection(),
      value()
    ])
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
        ast: fn ast -> {:set, MapSet.new(List.flatten(ast))} end
      )
    end)
  end

  # Binding

  # Bindings are a special kind of list value
  # They are formed of a prefix: value but only support specific kinds of
  # value that are used for value binding

  def bound_value() do
    choice(
      [
        elem_ref_value(),
        binding_path(),
        code_block_value(),
        function_value()
      ],
      label: "bound-value",
      debug: true
    )
  end

  def list_binding() do
    ParserCache.get_parser("list_binding", fn ->
      sequence(
        [
          js_identifier(),
          ignore(colon()),
          iws(),
          optional(star()),
          bound_value()
        ],
        ast: fn
          [prefix, value] ->
            {:list_binding, {prefix, false, value}}

          [prefix, _deref, value] ->
            {:list_binding, {prefix, true, value}}
        end
      )
    end)
  end

  # List

  def list_value() do
    choice([
      collection_value(),
      list_binding()
    ])
  end

  def list() do
    ParserCache.get_parser("list", fn ->
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          optional(
            sequence([
              list_value(),
              many(
                sequence([
                  iws(),
                  ignore(optional(sequence([comma(), iws()]))),
                  list_value()
                ])
              )
            ])
          ),
          iows(),
          ignore(close_bracket())
        ],
        label: "list-value",
        debug: true,
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

  def table_attribute() do
    sequence(
      [
        js_identifier(),
        ignore(colon()),
        iws(),
        commit(),
        collection_value()
      ],
      label: "attribute",
      debug: true,
      ast: fn [id, {type, value}] ->
        %Rez.AST.Attribute{name: id, type: type, value: value}
      end
    )
  end

  def table() do
    ParserCache.get_parser("table", fn ->
      sequence(
        [
          ignore(open_brace()),
          iows(),
          optional(
            many(
              sequence(
                [
                  iows(),
                  table_attribute()
                ],
                ast: fn [attribute] -> attribute end
              )
            )
          ),
          iows(),
          ignore(close_brace())
        ],
        label: "table-value",
        debug: true,
        ast: fn [ast] ->
          Enum.reduce(ast, %{}, fn %Rez.AST.Attribute{name: name} = attr, table ->
            Map.put(table, name, attr)
          end)
        end
      )
      |> transform(fn table -> {:table, table} end)
    end)
  end

  # Collection

  def collection() do
    choice([
      lazy(set()),
      lazy(list()),
      lazy(table()),
      probability_table()
    ])
  end
end
