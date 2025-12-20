defmodule Rez.Parser.BTreeParser do
  @moduledoc """
  Implements the parser for Behaviour Trees
  """

  import Ergo.Combinators,
    only: [
      ignore: 1,
      choice: 2,
      lazy: 1,
      lookahead: 1,
      many: 2,
      optional: 1,
      sequence: 1,
      sequence: 2
    ]

  import Rez.Parser.UtilityParsers,
    only: [
      caret: 0,
      iws: 0,
      iows: 0,
      equals: 0,
      amp: 0,
      open_bracket: 0,
      close_bracket: 0
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]
  import Rez.Parser.ValueParsers, only: [value: 0]
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  # import Rez.Parser.Trace

  def bt_parser() do
    cached_parser(
      sequence(
        [
          lookahead(sequence([caret(), open_bracket()])),
          ignore(caret()),
          bt_node()
        ],
        label: "btree",
        ast: fn [node] ->
          {:bht, node}
        end
      )
    )
  end

  def bt_node() do
    cached_parser(
      choice(
        [
          bt_template_ref(),
          bt_instance(),
          bt_empty()
        ],
        label: "bt_node"
      )
    )
  end

  def bt_template_ref() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          ignore(amp()),
          iows(),
          js_identifier(),
          iows(),
          ignore(close_bracket())
        ],
        label: "bt_template_ref",
        ast: fn [template_id] ->
          {:template, template_id}
        end
      )
    )
  end

  def bt_empty() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          ignore(close_bracket())
        ],
        label: "bt_empty",
        ast: fn [] ->
          {:empty, %{}, []}
        end
      )
    )
  end

  def bt_instance() do
    cached_parser(
      sequence(
        [
          ignore(open_bracket()),
          iows(),
          js_identifier(),
          optional(bt_options()),
          optional(bt_children()),
          iows(),
          ignore(close_bracket())
        ],
        label: "bt_instance",
        ast: fn ast ->
          case ast do
            [node_type] ->
              {node_type, %{}, []}

            [node_type, options] when is_map(options) ->
              {node_type, options, []}

            [node_type, children] when is_list(children) ->
              {node_type, %{}, children}

            [node_type, options, children] when is_map(options) and is_list(children) ->
              {node_type, options, children}
          end
        end
      )
    )
  end

  def bt_options() do
    cached_parser(
      many(
        sequence([
          iws(),
          js_identifier(),
          iows(),
          ignore(equals()),
          iows(),
          value()
        ]),
        label: "bt_options",
        ast: fn name_value_pairs ->
          Enum.reduce(name_value_pairs, %{}, fn [name, value], options ->
            Map.put(options, name, value)
          end)
        end
      )
    )
  end

  def bt_children() do
    cached_parser(
      many(
        sequence([
          iws(),
          lazy(bt_node())
        ]),
        ast: fn ast -> List.flatten(ast) end
      )
    )
  end
end
