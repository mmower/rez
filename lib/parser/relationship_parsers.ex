defmodule Rez.Parser.RelationshipParsers do
  alias Rez.Parser.ParserCache

  alias Rez.AST.Relationship

  alias Ergo.Context

  import Ergo.Combinators,
    only: [ignore: 1, sequence: 1, sequence: 2, choice: 2, many: 1, optional: 1]

  import Ergo.Meta, only: [commit: 0]

  alias Rez.Parser.ValueParsers
  alias Rez.Parser.StructureParsers

  import Rez.Parser.ValueParsers, only: [keyword_value: 0]

  import Rez.Parser.UtilityParsers,
    only: [iliteral: 1, iws: 0, iows: 0, hash: 0, open_brace: 0, close_brace: 0]

  def tagset() do
    ParserCache.get_parser("tagset_value", fn ->
      sequence(
        [
          ignore(hash()),
          ignore(open_brace()),
          many(
            sequence([
              iows(),
              keyword_value()
            ])
          ),
          iows(),
          ignore(close_brace())
        ],
        label: "tagset-value",
        debug: true,
        ast: fn ast -> {:set, MapSet.new(List.flatten(ast))} end
      )
    end)
  end

  def rel_affinity() do
    ParserCache.get_parser("rel_value", fn ->
      choice(
        [
          ValueParsers.dice_value(),
          ValueParsers.number_value(),
          ValueParsers.function_value(),
          ValueParsers.dynamic_initializer_value()
        ],
        label: "value",
        debug: true
      )
    end)
  end

  def make_relationship(source_file, source_line, col, source_id, target_id, affinity, tags) do
    Relationship.make(source_id, target_id, affinity, tags)
    |> Map.put(:position, {source_file, source_line, col})
  end

  def relationship_directive() do
    sequence(
      [
        iliteral("@rel"),
        iws(),
        commit(),
        ValueParsers.elem_ref_value(),
        iws(),
        ValueParsers.elem_ref_value(),
        iws(),
        rel_affinity(),
        optional(
          sequence([
            iws(),
            tagset()
          ])
        )
      ],
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: ast,
                data: %{source: source}
              } = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          case ast do
            [{:elem_ref, source_id}, {:elem_ref, target_id}, affinity, [{:set, tags}]] ->
              make_relationship(
                source_file,
                source_line,
                col,
                source_id,
                target_id,
                affinity,
                tags
              )

            [{:elem_ref, source_id}, {:elem_ref, target_id}, affinity] ->
              make_relationship(
                source_file,
                source_line,
                col,
                source_id,
                target_id,
                affinity,
                MapSet.new()
              )
          end

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
