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

  alias Rez.AST.Attribute
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  import Rez.Parser.{UtilityParsers, AttributeParser, DelimitedParser}
  import Rez.Parser.IdentifierParser, only: [js_identifier: 1]
  import Rez.Parser.DefaultParser, only: [default: 2]

  import Rez.Utils, only: [attr_list_to_map: 1]

  def attribute_list() do
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
  end

  def attribute_and_child_list(child_parser) do
    many(
      sequence(
        [
          iws(),
          choice(
            [
              child_parser,
              attribute()
            ],
            debug: true,
            label: "attr_or_child_elem"
          )
        ],
        debug: true,
        label: "attr_or_child",
        ast: &List.first/1
      ),
      debug: true,
      label: "attr_and_child_list",
      ast: fn ast ->
        # Split the list into a tuple of lists {children (structs), attributes}
        Enum.split_with(ast, &is_struct(&1, Rez.AST.Attribute))
      end
    )
  end

  def merge_attributes(default_attributes, attributes, parent_objects) do
    merge_list = fn _key, old, new -> old ++ new end

    default_attributes
    |> Map.merge(attributes)
    |> Map.merge(%{"_parents" => Attribute.list("_parents", parent_objects)}, merge_list)
  end

  @doc """
  `create_block` returns a struct instance filling in the meta attributes
  related to parsing.
  """
  def create_block(block_struct, id, parent_objects, attributes, source_file, source_line, col)
      when is_list(parent_objects) and is_map(attributes) and is_binary(source_file) do
    node =
      struct(
        block_struct,
        id: id,
        position: {source_file, source_line, col}
      )

    NodeHelper.pre_process(%{
      node
      | attributes:
          merge_attributes(
            Node.default_attributes(node),
            attributes,
            parent_objects
          )
    })
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

  # Parser for a block that has no author assigned id or children. The id_fn
  # parameter is expected to return a generated ID, otherwise a random ID will
  # be assigned. The id_fn is passed the map of attributes
  def block(label, block_struct, id_fn) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        commit(),
        block_begin(label),
        attribute_list(),
        iws(),
        block_end(label)
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
          "#{to_string(block_struct)}/#{label} @ #{line}:#{col}"
        )
      end
    )
  end

  def parents(parent_ast) do
    parent_ast
    |> List.flatten()
    |> Enum.map(fn elem -> {:keyword, elem} end)
  end

  def parent_objects() do
    optional(
      sequence(
        [
          ignore(left_angle_bracket()),
          iows(),
          elem_tag() |> atom(),
          many(
            sequence([
              iows(),
              ignore(comma()),
              iows(),
              elem_tag() |> atom()
            ])
          ),
          iows(),
          ignore(right_angle_bracket())
        ],
        ast: fn ast ->
          {:parent_objects, parents(ast)}
        end
      )
    )
    |> default({:parent_objects, []})
  end

  def block_with_id(label, block_struct) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        parent_objects(),
        iws(),
        block_begin(label),
        attribute_list(),
        iws(),
        block_end(label)
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id, {:parent_objects, parent_objects}, attr_list | []],
                data: %{source: source}
              } = ctx ->
        attributes = attr_list_to_map(attr_list)
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          create_block(
            block_struct,
            id,
            parent_objects,
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

  def block_with_id_opt_attributes(label, block_struct) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        parent_objects(),
        optional(
          sequence(
            [
              iws(),
              block_begin(label),
              attribute_list(),
              iws(),
              block_end(label)
            ],
            ast: &List.first/1
          )
        )
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{entry_points: [{line, col} | _], ast: ast, data: %{source: source}} = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        {id, block} =
          case ast do
            [id, {:parent_objects, parent_objects}] ->
              {id,
               create_block(block_struct, id, parent_objects, %{}, source_file, source_line, col)}

            [id, {:parent_objects, parent_objects}, attr_list] ->
              {id,
               create_block(
                 block_struct,
                 id,
                 parent_objects,
                 attr_list_to_map(attr_list),
                 source_file,
                 source_line,
                 col
               )}
          end

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

  @doc """
  At the moment @game is the only id-less block with children
  """
  def block_with_children(label, id_fn, block_struct, child_parser, add_fn)
      when is_function(add_fn) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        commit(),
        block_begin(label),
        attribute_and_child_list(child_parser),
        iws(),
        block_end(label)
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [{attr_list, children} | []],
                data: %{source: source}
              } = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        attrs = attr_list_to_map(attr_list)
        id = id_fn.(attrs)

        block =
          Enum.reduce(
            children,
            create_block(
              block_struct,
              id,
              [],
              attrs,
              source_file,
              source_line,
              col
            ),
            add_fn
          )

        ctx_with_block_and_id_mapped(ctx, block, id, label, source_file, source_line)
      end,
      err: fn %Context{} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "#{to_string(block_struct)}/#{label}"
        )
      end
    )
  end

  def block_with_id_children(label, block_struct, child_parser, add_fn)
      when is_function(add_fn) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        commit(),
        js_identifier("#{label}_id"),
        parent_objects(),
        iws(),
        block_begin(label),
        attribute_and_child_list(child_parser),
        iws(),
        block_end(label)
      ],
      label: "#{label}-block",
      debug: true,
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id, {:parent_objects, parent_objects}, {attr_list, children} | []],
                data: %{source: source}
              } = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          Enum.reduce(
            children,
            create_block(
              block_struct,
              id,
              parent_objects,
              attr_list_to_map(attr_list),
              source_file,
              source_line,
              col
            ),
            add_fn
          )

        ctx_with_block_and_id_mapped(ctx, block, id, label, source_file, source_line)
      end,
      err: fn %Context{} = ctx ->
        Context.add_error(
          ctx,
          :block_not_matched,
          "#{to_string(block_struct)}/#{label}"
        )
      end
    )
  end

  def delimited_block(label, id_fn, block_struct) do
    sequence(
      [
        iliteral("@#{label}"),
        iws(),
        text_delimited_by_nested_parsers(open_brace(), close_brace(), trim: true)
      ],
      label: "#{label}-block",
      ctx: fn %Context{entry_points: [{line, col} | _], ast: [text], data: %{source: source}} =
                ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        id = id_fn.()
        attr = Attribute.string("$content", text)

        block =
          create_block(
            block_struct,
            id,
            [],
            %{
              "$content" => attr
            },
            source_file,
            source_line,
            col
          )

        ctx_with_block_and_id_mapped(
          ctx,
          block,
          id,
          label,
          source_file,
          source_line
        )
      end
    )
  end
end
