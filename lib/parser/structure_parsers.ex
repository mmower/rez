defmodule Rez.Parser.StructureParsers do
  @moduledoc """
  `Rez.Parser.StructureParsers` implements functions for "templated" parsers
  for blocks and lists which have a different directive but share internal
  structure, e.g. a block with an id and attributes.
  """
  alias Ergo.Context
  import Ergo.Combinators
  import Ergo.Meta

  alias LogicalFile

  import Rez.Parser.UtilityParsers
  import Rez.Parser.AttributeParser
  import Rez.Parser.IdentifierParser, only: [js_identifier: 1]
  import Rez.Utils, only: [attr_list_to_map: 1]
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  def attribute_list() do
    cached_parser(
      many(
        sequence(
          [
            iws(),
            attribute()
          ],
          label: "attr_list",
          ast: &List.first/1
        )
      )
    )
  end

  # def merge_attributes(default_attributes, attributes, []) do
  #   Map.merge(default_attributes, attributes)
  # end

  @doc """
  `create_block` returns a struct instance filling in the meta attributes
  related to parsing.
  """
  def create_block(block_struct, id, attributes, source_file, source_line, col)
      when is_map(attributes) and is_binary(source_file) do
    struct(block_struct, id: id, position: {source_file, source_line, col})
    |> Map.put(:attributes, attributes)
  end

  # Does the twin jobs of setting the AST to point to the block and map the ID of
  # into the id_map.
  #
  # The present behaviour with the id_map is to:
  # where there is no entry for the id, create an entry id -> {label, file, line}
  # where there is an entry for the id, create an entry id -> [{existing_label, file, line}, {new_label, file, line}]
  # where there is a list for the id, create an entry id -> [{new_label, file, line} | contents]
  #
  # In general we do not support using the same ID twice.
  def ctx_with_block_and_id_mapped(
        %Context{data: %{id_map: id_map} = data} = ctx,
        block,
        id,
        label,
        file,
        line
      ) do
    case Map.get(id_map, id) do
      nil ->
        %{ctx | ast: block, data: %{data | id_map: Map.put(id_map, id, {label, file, line})}}

      {o_label, o_file, o_line} ->
        %{
          ctx
          | ast: block,
            data: %{
              data
              | id_map: Map.put(id_map, id, [{label, file, line}, {o_label, o_file, o_line}])
            }
        }

      matches when is_list(matches) ->
        %{
          ctx
          | ast: block,
            data: %{data | id_map: Map.put(id_map, id, [{label, file, line} | matches])}
        }
    end
  end

  # Parser for a block that has a directly assigned id
  def block(label, block_struct, id) when is_binary(id) do
    sequence(
      [
        iliteral("@#{label}"),
        not_lookahead(elem_body_char()),
        iws(),
        commit(),
        block_begin(),
        attribute_list(),
        iws(),
        block_end()
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)
        block = create_block(block_struct, id, attributes, source_file, source_line, col)
        ctx_with_block_and_id_mapped(ctx, block, id, label, source_file, source_line)
      end,
      err: fn %Context{entry_points: [{line, col} | _]} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "@#{label} starting L#{line}:#{col}"
        )
      end
    )
  end

  # Parser for a block that has no author assigned id or children. The id_fn
  # parameter is expected to return a generated ID, otherwise a random ID will
  # be assigned. The id_fn is passed the map of attributes
  def block(label, block_struct, id_fn) when is_function(id_fn, 1) do
    sequence(
      [
        iliteral("@#{label}"),
        not_lookahead(elem_body_char()),
        iws(),
        commit(),
        block_begin(),
        attribute_list(),
        iws(),
        block_end()
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)
        auto_id = id_fn.(attributes)
        block = create_block(block_struct, auto_id, attributes, source_file, source_line, col)
        ctx_with_block_and_id_mapped(ctx, block, auto_id, label, source_file, source_line)
      end,
      err: fn %Context{entry_points: [{line, col} | _]} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "@#{label} starting L#{line}:#{col}"
        )
      end
    )
  end

  def block_with_id(label, block_struct) do
    sequence(
      [
        iliteral("@#{label}"),
        not_lookahead(elem_body_char()),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        iws(),
        block_begin(),
        attribute_list(),
        iws(),
        block_end()
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id, attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)
        block = create_block(block_struct, id, attributes, source_file, source_line, col)
        ctx_with_block_and_id_mapped(ctx, block, id, label, source_file, source_line)
      end,
      err: fn %Context{entry_points: [{line, col} | _]} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "#{to_string(block_struct)}/#{label} @ #{line}:#{col}"
        )
      end
    )
  end

  # Like `block_with_id/2`, but the parsed id is *not* registered in the
  # shared `id_map` — it is purely local to whatever parent block embeds
  # this one (e.g. a `@contains` block nested inside an `@inventory`).
  def block_with_local_id(label, block_struct) do
    sequence(
      [
        iliteral("@#{label}"),
        not_lookahead(elem_body_char()),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        iws(),
        block_begin(),
        attribute_list(),
        iws(),
        block_end()
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id, attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)
        block = create_block(block_struct, id, attributes, source_file, source_line, col)
        %{ctx | ast: block}
      end,
      err: fn %Context{entry_points: [{line, col} | _]} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "#{to_string(block_struct)}/#{label} @ #{line}:#{col}"
        )
      end
    )
  end

  # Parses a block body as a mixture of attributes and nested child blocks
  # (parsed with `child_parser`), splitting the result into
  # `{attributes, children}`.
  def attribute_and_child_list(child_parser) do
    many(
      sequence(
        [
          iws(),
          choice([child_parser, attribute()], label: "attr_or_child")
        ],
        ast: &List.first/1
      ),
      ast: fn items -> Enum.split_with(items, &is_struct(&1, Rez.AST.Attribute)) end
    )
  end

  # Like `block_with_id/2`, but the block body is `attribute_and_child_list/1`
  # rather than `attribute_list/0`. The parsed children are stashed under
  # `metadata["nested_contains"]` on the resulting block.
  def block_with_id_and_children(label, block_struct, child_parser) do
    sequence(
      [
        iliteral("@#{label}"),
        not_lookahead(elem_body_char()),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        iws(),
        block_begin(),
        attribute_and_child_list(child_parser),
        iws(),
        block_end()
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id, {attr_list, children} | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          create_block(block_struct, id, attributes, source_file, source_line, col)
          |> Map.put(:metadata, %{"nested_contains" => children})

        ctx_with_block_and_id_mapped(ctx, block, id, label, source_file, source_line)
      end,
      err: fn %Context{entry_points: [{line, col} | _]} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "#{to_string(block_struct)}/#{label} @ #{line}:#{col}"
        )
      end
    )
  end
end
