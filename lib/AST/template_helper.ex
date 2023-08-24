defmodule Rez.AST.TemplateHelper do
  @moduledoc """
  Tools to convert attributes representing templates into Rez pre-compiled
  template expression functions.
  """
  alias Rez.AST.NodeHelper
  alias Rez.Debug
  import Rez.Utils

  alias Rez.Compiler.TemplateCompiler
  alias Rez.Parser.TemplateParser

  def prepare_content(markup) when is_binary(markup) do
    markup
    |> string_to_lines()
    |> Enum.map_join("\n", &String.trim/1)
  end

  def convert_markdown(markup) do
    markup
    |> prepare_content()
    |> Earmark.as_html!(escape: false, smartypants: false)
  end

  def convert_markup(markup, "html"), do: markup
  def convert_markup(markup, "markdown"), do: convert_markdown(markup)

  def make_template(
        %{id: id} = node,
        source_attr,
        html_processor \\ &Function.identity/1
      )
      when is_binary(source_attr) and is_function(html_processor) do
    markup = NodeHelper.get_attr_value(node, source_attr, "")
    format = NodeHelper.get_attr_value(node, "format", "markdown")

    html =
      markup
      |> prepare_content()
      |> convert_markup(format)
      |> html_processor.()

    if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.html", html)

    template = TemplateParser.parse(html)
    if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.t1", inspect(template))

    compiled_template = TemplateCompiler.compile(template)
    if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.t2", compiled_template)

    template =
      html
      |> TemplateParser.parse()
      |> TemplateCompiler.compile()

    NodeHelper.set_template_attr(
      node,
      "#{source_attr}_template",
      template
    )
  end
end
