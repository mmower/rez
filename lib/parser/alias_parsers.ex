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
      at: 0,
      equals: 0,
      hash: 0,
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

  def tag() do
    sequence(
      [
        ignore(at()),
        elem_tag()
      ],
      label: "tag",
      ast: &List.first/1
    )
  end

  defp alias_ctx(
         %Context{ast: [alias_tag, target_tag, attributes], data: %{aliases: aliases} = data} =
           ctx
       ) do
    legal_alias = not is_reserved_tag_name?(alias_tag)
    legal_target = is_reserved_tag_name?(target_tag)

    case {legal_alias, legal_target} do
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

      {true, true} ->
        %{
          ctx
          | ast: nil,
            data: %{
              data
              | aliases: Map.put(aliases, alias_tag, {target_tag, attr_list_to_map(attributes)})
            }
        }
    end
  end

  def alias_define() do
    sequence(
      [
        iliteral("@alias"),
        iws(),
        elem_tag(),
        iws(),
        ignore(equals()),
        iws(),
        elem_tag(),
        iws(),
        ignore(hash()),
        iws(),
        block_begin("alias"),
        attribute_list(),
        iws(),
        block_end("alias")
      ],
      debug: true,
      label: "alias-use",
      ctx: &alias_ctx/1
    )
  end

  @doc """
  Merge the default attribute map (from the alias) with the defined attribute map
  (from the use of the alias). Wherever there is an attribute defined in both, use
  the value from the definition with the exception of the "tags" attribute. In the
  case of "tags" merge the two tag sets.
  """
  def merge_attributes(default_attrs, defined_attrs) do
    Map.merge(default_attrs, defined_attrs, fn key, default_value, defined_value ->
      case key do
        "tags" ->
          with %{value: default_tags} <- default_value,
               %{value: defined_tags} <- defined_value do
            %{defined_value | value: MapSet.union(default_tags, defined_tags)}
          else
            _ ->
              defined_value
          end

        _ ->
          defined_value
      end
    end)
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

          {target_tag, default_attrs} ->
            target_module = NodeHelper.node_for_tag(target_tag)
            defined_attrs = attr_list_to_map(attr_list)
            attributes = merge_attributes(default_attrs, defined_attrs)
            {source_file, source_line} = LogicalFile.resolve_line(source, line)

            block =
              create_block(target_module, alias_id, attributes, source_file, source_line, col)

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

  # @doc """
  # Called to resolve an alias, i.e. translate the use of an aliased tag into
  # a use of its underlying tag with the aliased attributes in place.
  # """
  # def alias_to_object(target_tag, default_attrs, alias_id, attributes) do
  #   IO.puts("alias_to_object({#{target_tag}, ...}, #{alias_id}, ...)")

  #   target_module = NodeHelper.node_for_tag(target_tag)
  #   merged_attributes = Map.merge(alias_attributes, attributes)

  #   create_block(target_module, alias_id, merged_attributes, )

  #   with module when not is_nil(module) <- NodeHelper.node_for_tag(original_tag) do
  #     struct(module, id: alias_id, attributes: Map.merge(alias_attributes, attributes))
  #   end
  # end
end
