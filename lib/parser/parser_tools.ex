defmodule Rez.Parser.ParserTools do
  @moduledoc """
  Implements utility functions intended to be used in parser ast: or ctx:
  callbacks.
  """
  alias Ergo.Context

  def resolve_position(%Context{entry_points: [{line, col} | _], data: %{source: source}}) do
    {source_file, source_line} = LogicalFile.resolve_line(source, line)
    {source_file, source_line, col}
  end
end
