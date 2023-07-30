defmodule Rez.AST.TemplateHelper do
  @moduledoc """
  Tools to convert attributes representing templates into Handlebars pre-compiled
  template functions.
  """
  alias Rez.AST.NodeHelper
  alias Rez.{Debug, Handlebars}
  import Rez.Utils

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

    case Handlebars.compile(html, "#{id}/#{source_attr}") do
      {:ok, template} ->
        NodeHelper.set_template_attr(node, "#{source_attr}_template", template)

      {:error, message} ->
        NodeHelper.add_error(node, message)
    end
  end
end
