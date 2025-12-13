defmodule Rez.Parser.AliasParsers do
  @moduledoc """
  `Rez.Parser.AliasParsers` implements the parsers for the `@alias` directive
  and expands aliases.
  """

  alias Ergo.Context
  import Ergo.Combinators, only: [ignore: 1, sequence: 2]
  import Ergo.Meta, only: [commit: 0]

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper

  import Rez.Parser.StructureParsers
  import Rez.Parser.ParserTools

  import Rez.Parser.UtilityParsers,
    only: [
      iws: 0,
      iows: 0,
      at: 0,
      equals: 0,
      elem_tag: 0,
      iliteral: 1,
      block_begin: 0,
      block_end: 0
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 1]
  import Rez.Utils, only: [attr_list_to_map: 1]
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  # The "right" way of doing this is still pretty brittle so I accept that
  # I will at some point forget to update this when I add a new element.
  @legal_targets [
    "asset",
    "actor",
    "behaviour",
    "card",
    "effect",
    "faction",
    "generator",
    "group",
    "inventory",
    "list",
    "object",
    "plot",
    "scene",
    "slot",
    "system",
    "timer"
  ]

  @reserved_names [
    "asset",
    "actor",
    "behaviour",
    "card",
    "effect",
    "faction",
    "filter",
    "game",
    "generator",
    "group",
    "inventory",
    "list",
    "mixin",
    "object",
    "patch",
    "plot",
    "rel",
    "scene",
    "script",
    "slot",
    "style",
    "system",
    "timer"
  ]

  def legal_alias_name?(name, defined_aliases)
      when is_binary(name) and is_list(defined_aliases) do
    not (name in @reserved_names || name in defined_aliases)
  end

  def legal_alias_target?(name, defined_aliases)
      when is_binary(name) and is_list(defined_aliases) do
    name in @legal_targets || name in defined_aliases
  end

  def alias_directive() do
    cached_parser(
      sequence(
        [
          iliteral("@elem"),
          iws(),
          commit(),
          elem_tag(),
          iows(),
          ignore(equals()),
          iows(),
          elem_tag(),
          mixins()
        ],
        label: "elem",
        ctx: fn %Context{
                  ast: [alias_tag, target_tag, mixins],
                  data: %{aliases: aliases} = data
                } = ctx ->
          existing_aliases = Map.keys(aliases)

          case {legal_alias_name?(alias_tag, existing_aliases),
                legal_alias_target?(target_tag, existing_aliases)} do
            {false, _} ->
              ctx
              |> Context.add_error(
                :illegal_tag_name,
                "#{alias_tag} is not a legal tag for an @elem alias"
              )
              |> Context.make_error_fatal()

            {_, false} ->
              ctx
              |> Context.add_error(
                :illegal_tag_name,
                "#{target_tag} is not a valid target to be aliased as an @elem"
              )
              |> Context.make_error_fatal()

            _ ->
              alias = %Rez.AST.Alias{
                position: resolve_position(ctx),
                name: alias_tag,
                target: target_tag,
                mixins: mixins
              }

              %{
                ctx
                | ast: alias,
                  data: %{
                    data
                    | aliases: Map.put(aliases, alias_tag, {target_tag, mixins})
                  }
              }
          end
        end
      )
    )
  end

  def aliased_struct(tag, aliases) when is_binary(tag) and is_map(aliases) do
    case Map.get(aliases, tag) do
      nil ->
        NodeHelper.node_for_tag(tag)

      {alias, _mixins} ->
        aliased_struct(alias, aliases)
    end
  end

  @doc """
  The `aliased_element/0` parser
  """
  def aliased_element() do
    cached_parser(
      sequence(
        [
          ignore(at()),
          elem_tag(),
          iws(),
          js_identifier("alias_id"),
          iws(),
          block_begin(),
          attribute_list(),
          iws(),
          block_end()
        ],
        label: "alias-block",
        debug: true,
        ctx: fn %Context{
                  ast: [alias_tag, alias_id, attr_list],
                  entry_points: [{line, col} | _],
                  data: %{source: source, aliases: aliases}
                } = ctx ->
          case Map.get(aliases, alias_tag) do
            nil ->
              ctx
              |> Context.add_error(:undefined_alias, "Undefined alias #{alias_tag} found.")
              |> Context.make_error_fatal()

            {target_tag, {:mixins, mixins}} ->
              target_module = aliased_struct(target_tag, aliases)
              attributes = attr_list_to_map(attr_list ++ [Attribute.string("$alias", alias_tag)])
              {source_file, source_line} = LogicalFile.resolve_line(source, line)

              block =
                create_block(
                  target_module,
                  alias_id,
                  mixins,
                  attributes,
                  source_file,
                  source_line,
                  col
                )

              ctx_with_block_and_id_mapped(
                ctx,
                block,
                alias_id,
                target_tag,
                source_file,
                source_line
              )
          end
        end
      )
    )
  end
end
