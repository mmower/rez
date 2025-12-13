defmodule Rez.Parser.SpecialElementParsers do
  @moduledoc """
  Implements parsers for special elements that don't have a unique id and
  therefore must be handled separately.
  """
  import Ergo.Combinators
  import Ergo.Meta

  alias Ergo.Context

  import Rez.Parser.DelimitedParser
  import Rez.Parser.UtilityParsers
  import Rez.Parser.StructureParsers
  import Rez.Parser.ParserTools
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  alias Rez.Utils

  def patch_element() do
    cached_parser(
      sequence(
        [
          iliteral("@patch"),
          iws(),
          commit(),
          block_begin(),
          attribute_list(),
          iws(),
          block_end()
        ],
        label: "patch-block",
        ctx: fn %Context{ast: [attr_list]} = ctx ->
          %{
            ctx
            | ast: %Rez.AST.Patch{
                position: resolve_position(ctx),
                attributes: Utils.attr_list_to_map(attr_list)
              }
          }
        end
      )
    )
  end

  def script_element() do
    cached_parser(
      sequence(
        [
          iliteral("@script"),
          iws(),
          text_delimited_by_nested_parsers(open_brace(), close_brace(), trim: true)
        ],
        label: "script-block",
        ctx: fn %Context{ast: [script]} = ctx ->
          %{
            ctx
            | ast: %Rez.AST.Script{
                position: resolve_position(ctx),
                script: script
              }
          }
        end
      )
    )
  end

  def styles_element() do
    cached_parser(
      sequence(
        [
          iliteral("@styles"),
          iws(),
          text_delimited_by_nested_parsers(open_brace(), close_brace(), trim: true)
        ],
        label: "styles-block",
        ctx: fn %Context{ast: [styles]} = ctx ->
          %{
            ctx
            | ast: %Rez.AST.Style{
                position: resolve_position(ctx),
                styles: styles
              }
          }
        end
      )
    )
  end

  def special_element() do
    cached_parser(
      choice([
        patch_element(),
        script_element(),
        styles_element()
      ])
    )
  end
end
