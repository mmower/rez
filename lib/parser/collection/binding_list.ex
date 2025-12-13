defmodule Rez.Parser.Collection.BindingList do
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  import Ergo.Combinators,
    only: [
      sequence: 1,
      sequence: 2,
      choice: 1,
      choice: 2,
      optional: 1,
      many: 1,
      ignore: 1,
      lazy: 1
    ]

  import Rez.Parser.UtilityParsers,
    only: [iows: 0, iws: 0, open_bracket: 0, close_bracket: 0, comma: 0, colon: 0, star: 0]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]

  import Rez.Parser.JSBindingParser, only: [binding_path: 0]

  import Rez.Parser.ValueParsers,
    only: [
      string_value: 0,
      number_value: 0,
      bool_value: 0,
      elem_ref_value: 0,
      function_value: 0,
      code_block_value: 0
    ]

  import Rez.Parser.Collection.List, only: [list: 0]

  def binding_list() do
    cached_parser(
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
    )
  end

  def list_binding() do
    cached_parser(
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
    )
  end

  # Binding

  # Bindings are a special kind of list value
  # They are formed of a prefix: value but only support specific kinds of
  # value that are used for value binding

  def bound_literal() do
    cached_parser(
      choice(
        [
          string_value(),
          number_value(),
          bool_value(),
          lazy(list())
        ],
        label: "bound-literal",
        ast: fn value ->
          {:literal, value}
        end
      )
    )
  end

  def bound_source() do
    cached_parser(
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
    )
  end
end
