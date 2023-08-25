defmodule Rez.Compiler.CommentMacro do
  @behaviour LogicalFile.Macro

  alias LogicalFile.Section

  @moduledoc """
  """

  @impl LogicalFile.Macro
  def apply_macro(%LogicalFile{} = file, _options \\ []) do
    process_comments(file)
  end

  @impl LogicalFile.Macro
  def invocation(options) when is_list(options) do
    {__MODULE__, []}
  end

  @match_expr ~r/%%/
  @replace_expr ~r/(.*?)(%%.*)/

  def replace_comment(_, content, comment) do
    content <> String.duplicate(" ", String.length(comment))
  end

  @doc """
  The general strategy is to process sections in order.
  For each section find any line matching the expression and
  transform the entire contents of the line into whitespace.
  """
  def process_comments(%LogicalFile{} = file) do
    processed_sections =
      file
      |> LogicalFile.sections_in_order()
      |> Enum.map(fn section ->
        section
        |> Section.lines_matching(@match_expr)
        |> Enum.reduce(section, fn {lno, _line}, updated_section ->
          Section.update_line(
            updated_section,
            lno,
            fn line ->
              Regex.replace(@replace_expr, line, &replace_comment/3)
            end
          )
        end)
      end)

    %{file | sections: LogicalFile.sections_to_map(processed_sections)}
  end
end
