defmodule Rez.Parser.RelationshipParsers do
  alias Rez.AST.Attribute
  alias Ergo.Context

  import Ergo.Combinators

  import Ergo.Meta, only: [commit: 0]

  import Rez.Utils, only: [attr_list_to_map: 1]

  import Rez.Parser.UtilityParsers
  alias Rez.Parser.StructureParsers
  alias Rez.Parser.ValueParsers

  def relationship_elem() do
    sequence(
      [
        iliteral("@rel"),
        iws(),
        commit(),
        ValueParsers.elem_ref_value(),
        iws(),
        ValueParsers.elem_ref_value(),
        iws(),
        block_begin(),
        StructureParsers.attribute_list(),
        iows(),
        block_end()
      ],
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [{:elem_ref, source_id}, {:elem_ref, target_id}, attr_list],
                data: %{source: source}
              } = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        rel_id = "rel_#{source_id}_#{target_id}"

        attributes =
          attr_list_to_map(attr_list)
          |> Map.put("source", Attribute.elem_ref("source", source_id))
          |> Map.put("target", Attribute.elem_ref("target", target_id))

        block =
          StructureParsers.create_block(
            Rez.AST.Relationship,
            rel_id,
            [],
            attributes,
            source_file,
            source_line,
            col
          )

        StructureParsers.ctx_with_block_and_id_mapped(
          ctx,
          block,
          block.id,
          block.id,
          source_file,
          source_line
        )
      end
    )
  end
end
