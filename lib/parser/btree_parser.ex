defmodule Rez.Parser.BTreeParser do
  @moduledoc """
  Implements the parser for Behaviour Trees
  """

  alias Rez.AST.Attribute
  import Ergo.Combinators
  import Rez.Parser.UtilityParsers
  import Rez.Parser.AttributeParser, only: [js_identifier: 0, table_value: 0]
  import Rez.Utils, only: [map_to_map: 2]

  def bt_parser() do
    sequence(
      [
        lookahead(sequence([caret(), open_bracket()])),
        ignore(caret()),
        bt_node()
      ],
      ast: fn [node] ->
        {:btree, node}
      end
    )
  end

  def bt_node() do
    sequence([
      ignore(open_bracket()),
      iows(),
      bt_selector(),
      optional(
        sequence([
          iws(),
          bt_options()
        ]) |> hoist()),
      optional(
        sequence([
          iws(),
          bt_children()
        ]) |> hoist()),
      iows(),
      ignore(close_bracket())
    ],
    ast: fn ast ->
      case ast do
        [selector] ->
          {:node, selector, %{}, []}

        [selector, %{} = options] ->
          {:node, selector, options, []}

        [selector, children] when is_list(children) ->
          {:node, selector, %{}, children}

        [selector, %{} = options, children] when is_list(children) ->
          {:node, selector, options, children}
      end
    end)
  end

  def bt_selector() do
    sequence([
      js_identifier(),
      optional(
        sequence([
          ignore(forward_slash()),
          js_identifier()
        ])
      )
    ],
    ast: fn ast ->
      case ast do
        [behaviour] ->
          {"rez", behaviour}

        [namespace, [behaviour]] ->
          {namespace, behaviour}
      end
    end)
  end

  def convert_attribute_table_to_plain_map(table) do
    map_to_map(table, fn %Attribute{type: type, value: value} ->
      {type, value}
    end)
  end

  def bt_options() do
    table_value()
    |> transform(fn {:table, table} -> convert_attribute_table_to_plain_map(table) end)
  end

  def bt_children() do
    sequence([
      ignore(open_bracket()),
      iows(),
      lazy(bt_node()),
      many(
        sequence([
          iws(),
          lazy(bt_node())
        ])
      ),
      iows(),
      ignore(close_bracket())
    ],
    debug: true,
    ast: fn ast ->
      List.flatten(ast)
    end)
  end

end
