defmodule Rez.Parser.RelationshipParsers do
  @moduledoc """
  Implements parsers for @rel relationship elements that have a different
  syntax.

  @rel source_id -> target_id {
    ..attributes..
  }

  Such elements get an automatic id composed of
  "rel_<source_id>_<target_id>

  So
  @rel player -> enemy {
  }

  get the id #rel_player_enemy

  Since relationships are unidirectional, this would be different to

  @rel enemy -> player

  which would be #rel_enemy_player.
  """
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
        iows(),
        iliteral("->"),
        iows(),
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
          |> Map.put("source_id", Attribute.elem_ref("source_id", source_id))
          |> Map.put("target_id", Attribute.elem_ref("target_id", target_id))

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
