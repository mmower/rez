defmodule Rez.Parser.BTreeParser do
  @moduledoc """
  Implements the parser for Behaviour Trees
  """

  import Ergo.Combinators, only: [
    choice: 1,
    ignore: 1,
    lazy: 1,
    lookahead: 1,
    many: 1,
    many: 2,
    optional: 1,
    sequence: 1,
    sequence: 2
  ]

  import Rez.Parser.UtilityParsers, only: [
    caret: 0,
    iows: 0,
    equals: 0,
    open_bracket: 0,
    close_bracket: 0,
    forward_slash: 0
  ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 0]
  import Rez.Parser.ValueParsers, only: [value: 0]

  def bt_parser() do
    sequence(
      [
        lookahead(sequence([caret(), open_bracket()])),
        ignore(caret()),
        choice([
          bt_empty_node(),
          bt_node()
        ])
      ],
      label: "btree",
      ast: fn [node] ->
        {:btree, node}
      end
    )
  end

  def bt_empty_node() do
    sequence([
      open_bracket(),
      iows(),
      close_bracket()
    ],
    ast: fn _ -> [] end)
  end

  def progress(parser, message) do
    Ergo.Parser.combinator(
      :progress,
      "progress",
      fn ctx ->
        new_ctx = Ergo.Parser.invoke(ctx, parser)

        input = Ergo.Utils.printable_string(Ergo.Utils.ellipsize(new_ctx.input))

        case new_ctx.status do
          :ok ->
            IO.puts("OK  #{message} <<#{input}>>")

          {:error, _err} ->
            IO.puts("ERR #{message} <<#{input}>>")
        end

        new_ctx
      end,
      child_info: Ergo.Parser.child_info_for_telemetry(parser)
    )
  end

  def bt_node() do
    sequence([
        ignore(open_bracket()),
        iows(),
        bt_selector(),
        bt_options(),
        optional(bt_children()),
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
    err: fn ctx ->
      IO.puts("BT_SELECTOR failed")
      ctx
    end,
    ast: fn ast ->
      case ast do
        [behaviour] ->
          {"rez", behaviour}

        [namespace, [behaviour]] ->
          {namespace, behaviour}
      end
    end)
  end

  def bt_options() do
    many(
      sequence([
          iows(),
          js_identifier(),
          iows(),
          ignore(equals()),
          iows(),
          value()
      ]),
      ast: fn options ->
        Enum.reduce(options, %{}, fn [option, value], acc ->
          Map.put(acc, option, value)
        end)
      end
    )
  end

  def bt_children() do
    sequence([
      iows(),
      ignore(open_bracket()),
      many(
        sequence([
          iows(),
          lazy(bt_node())
        ])
      ),
      iows(),
      ignore(close_bracket()),
    ],
    debug: true,
    ast: fn ast ->
      List.flatten(ast)
    end)
  end

end
