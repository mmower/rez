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

  alias Rez.AST.NodeHelper

  import Rez.Parser.UtilityParsers
  import Rez.Parser.AttributeParser
  import Rez.Parser.IdentifierParser, only: [js_identifier: 1]
  import Rez.Parser.DefaultParser, only: [default: 2]
  import Rez.Parser.ValueParsers, only: [elem_ref_value: 0]

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

  # def merge_attributes(default_attributes, attributes, mixins) do
  #   merge_list = fn _key, old, new -> old ++ new end

  #   default_attributes
  #   |> Map.merge(attributes)
  #   |> Map.merge(%{"$mixins" => Attribute.list("$mixins", mixins)}, merge_list)
  # end

  @doc """
  `create_block` returns a struct instance filling in the meta attributes
  related to parsing.
  """
  def create_block(block_struct, id, mixins, attributes, source_file, source_line, col)
      when is_list(mixins) and is_map(attributes) and is_binary(source_file) do
    node =
      struct(
        block_struct,
        id: id,
        position: {source_file, source_line, col}
      )

    node
    |> Map.put(:attributes, attributes)
    |> NodeHelper.set_list_attr("$mixins", mixins)
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
        block = create_block(block_struct, id, [], attributes, source_file, source_line, col)
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
        block = create_block(block_struct, auto_id, [], attributes, source_file, source_line, col)
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
        mixins(),
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
                ast: [id, {:mixins, mixins}, attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          create_block(
            block_struct,
            id,
            mixins,
            attributes,
            source_file,
            source_line,
            col
          )

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

  def mixins() do
    cached_parser(
      optional(
        sequence(
          [
            ignore(left_angle_bracket()),
            iows(),
            commit(),
            elem_ref_value(),
            many(
              sequence([
                iows(),
                ignore(comma()),
                iows(),
                elem_ref_value()
              ])
            ),
            iows(),
            ignore(right_angle_bracket())
          ],
          ast: fn ast ->
            {:mixins, ast |> List.flatten()}
          end
        )
      )
      |> default({:mixins, []})
    )
  end
end
