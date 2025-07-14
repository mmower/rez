defmodule Rez.Parser.CommitTest do
  use ExUnit.Case

  alias Rez.Parser.Parser, as: RP
  alias LogicalFile.Section, as: LS

  def string_to_source(s) do
    lines = String.split(s, ~r/[\r\n]+/)
    section = LS.new("_", 1..Enum.count(lines), lines)
    LogicalFile.assemble("_", [section])
  end

  test "Catches error in structure" do
    source =
      string_to_source("""
      @actor random_person {
      }

      @object first_item {
      )
      """)

    ctx =
      Ergo.parse(RP.top_level(), to_string(source),
        data: %{source: source, aliases: %{}, id_map: %{}}
      )

    assert %{status: {:fatal, reasons}} = ctx
    error = List.last(reasons)
    assert {:unexpected_char, {4, 1}, "Expected: |}| Actual: |)|"} = error
  end
end
