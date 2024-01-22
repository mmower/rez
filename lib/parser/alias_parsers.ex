defmodule Rez.Parser.AliasParsers do
  @moduledoc """
  `Rez.Parser.AliasParsers` implements the parsers for the `@alias` directive
  and expands aliases.
  """

  alias Ergo.Context
  import Ergo.Combinators, only: [ignore: 1, sequence: 2]
  # import Ergo.Terminals, only: [char: 1, literal: 1]

  alias Rez.AST.NodeHelper

  # import Rez.Parser.AttributeParser
  import Rez.Parser.StructureParsers

  import Rez.Parser.UtilityParsers,
    only: [
      iws: 0,
      iows: 0,
      at: 0,
      equals: 0,
      elem_tag: 0,
      iliteral: 1,
      block_begin: 1,
      block_end: 1
    ]

  import Rez.Parser.IdentifierParser, only: [js_identifier: 1]
  import Rez.Utils, only: [attr_list_to_map: 1]

  def is_reserved_tag_name?(name) when is_binary(name) do
    NodeHelper.tag_defined?(name)
  end

  def alias_directive() do
    sequence(
      [
        iliteral("@alias"),
        iws(),
        elem_tag(),
        iows(),
        ignore(equals()),
        iows(),
        elem_tag(),
        parent_objects()
      ],
      label: "alias",
      ctx: fn %Context{
                ast: [alias_tag, target_tag, parent_objects],
                data: %{aliases: aliases} = data
              } = ctx ->
        case {not is_reserved_tag_name?(alias_tag), is_reserved_tag_name?(target_tag)} do
          {false, _} ->
            Context.add_error(
              ctx,
              :illegal_tag_name,
              "#{alias_tag} is not a legal tag for an alias"
            )

          {_, false} ->
            Context.add_error(
              ctx,
              :illegal_tag_name,
              "#{target_tag} is not a valid target to be aliased"
            )

          _ ->
            %{
              ctx
              | ast: nil,
                data: %{
                  data
                  | aliases: Map.put(aliases, alias_tag, {target_tag, parent_objects})
                }
            }
        end
      end
    )
  end

  @doc """
  The `alias_block` parser
  """
  def alias_block() do
    sequence(
      [
        ignore(at()),
        elem_tag(),
        iws(),
        js_identifier("alias_id"),
        iws(),
        block_begin("alias"),
        attribute_list(),
        iws(),
        block_end("alias")
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
            Context.add_error(ctx, :undefined_alias, "Undefined alias #{alias_tag} found.")

          {target_tag, {:parent_objects, parent_objects}} ->
            target_module = NodeHelper.node_for_tag(target_tag)
            attributes = attr_list_to_map(attr_list)
            {source_file, source_line} = LogicalFile.resolve_line(source, line)

            block =
              create_block(
                target_module,
                alias_id,
                parent_objects,
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
  end
end
