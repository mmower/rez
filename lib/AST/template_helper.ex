defmodule Rez.AST.TemplateHelper do
  @moduledoc """
  Tools to convert attributes representing templates into Rez pre-compiled
  template expression functions.
  """
  alias Rez.Debug
  import Rez.Utils

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.TemplateCompiler
  alias Rez.Parser.TemplateParser

  defmodule Transforms do
    @doc """
    Convert a link in the form [[*<attribute-name>]] into a dynamic link
    template expression using the `dynamic_link` filter to trigger a dynamic
    link that can generate a link, a disabled link, or nothing at all.
    """
    def convert_dynamic_links(text) do
      Regex.replace(~r/\[\[\*([\w\s]+)\]\]/, text, fn _, action ->
        ~s<${card | decision: "#{action}"}>
      end)
    end

    @doc ~S"""
    Converts a string like "First Card" into a card id "first_card"

    ## Examples
        iex> import Rez.AST.Card
        iex> assert "first_card" = convert_target_name_to_id("First Card")
    """
    def convert_target_name_to_id(target_name) do
      target_name
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
    end

    @doc """
    Convert a card link in the form "[[First Card]]" into a link which
    calls the card event handler.

    ## Examples
        iex> import Rez.AST.Card
        iex> assert "<a href='javascript:void(0)' data-event='card' data-target='first_card'>First Card</a>" = convert_target_name_links("[[First Card]]")
    """
    def convert_target_name_links(text) do
      Regex.replace(~r/\[\[([\w\s]+)\]\]/U, text, fn _, target_descriptor ->
        target_id = convert_target_name_to_id(target_descriptor)

        "<a href='javascript:void(0)' data-event='card' data-target='#{target_id}'>#{target_descriptor}</a>"
      end)
    end

    @card_regex ~r/\[\[([^|]+)\|([a-zA-Z_$][a-zA-Z0-9_$]*)(?:\s*,\s*([a-zA-Z0-9_-]+))?\]\]/U

    @doc """
    Convert a target link in the form `[[Title|id,class]]` into a link which
    loads the relevant card or scene.

    ## Examples
        iex> import Rez.AST.Card
        iex> assert "<a href='javascript:void(0)' data-event='card' data-target='new_scene_id'>New Scene</a>" = convert_target_id_links("[[New Scene|new_scene_id]]")
    """
    def convert_target_id_links(text) do
      converter = fn _, target_text, target_id, css_class ->
        ~s/${"#{target_id}" | card_link: "#{target_text}", "#{css_class}"}/
      end

      Regex.replace(@card_regex, text, converter)
    end

    @scene_switch_syntax ~r/\[\[([^|]*)\|\>\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

    @doc """
    Convert a link in the form `[[Title|><scene-id>]]` into a scene switch
    template expression.
    """
    def convert_scene_switch_links(text) do
      Regex.replace(@scene_switch_syntax, text, fn _, title, scene_id ->
        title = String.trim(title)
        "${card | scene_switch: \"#{scene_id}\", \"#{title}\"}"
      end)
    end

    @scene_interlude_syntax ~r/\[\[([^|]*)\|!\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

    @doc """
    Convert a link in the form `[[Title|!<scene-id>]]` into a scene interlude
    template expression.
    """
    def convert_scene_interlude_links(text) do
      Regex.replace(@scene_interlude_syntax, text, fn _, title, scene_id ->
        title = String.trim(title)

        "${card | scene_interlude: \"#{scene_id}\", \"#{title}\"}"
      end)
    end

    @scene_resume_syntax ~r/\[\[([^|]+)\|\s*!!\]\]/

    @doc """
    Converts a form `[[Link Text|!!]] into a scene resume template expression.
    """
    def convert_resume_links(text) do
      Regex.replace(@scene_resume_syntax, text, fn _, title ->
        title = String.trim(title)
        "${card | scene_resume: \"#{title}\"}"
      end)
    end

    # Events are [[Title|*event_name]]
    # E.g. [[Save Game|*save]]
    @event_syntax ~r/\[\[([^|]+)\|\*\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

    @doc """
    Convert a link in the form `[[Title|*<event_name>]]` e.g.
    `[[Load Game|load_game]]` into an event generator template expression,
    e.g. ${"load_game" | event: "Load Game"}
    """
    def convert_event_links(text) do
      Regex.replace(@event_syntax, text, fn _, title, event_name ->
        event_name = String.trim(event_name)
        title = String.trim(title)
        "${\"#{event_name}\" | event: \"#{title}\"}"
      end)
    end
  end

  def process_links(original_html) do
    original_html
    |> Transforms.convert_scene_switch_links()
    |> Transforms.convert_scene_interlude_links()
    |> Transforms.convert_resume_links()
    |> Transforms.convert_target_name_links()
    |> Transforms.convert_target_id_links()
    |> Transforms.convert_event_links()
    |> Transforms.convert_dynamic_links()
  end

  def prepare_content(markup) when is_binary(markup) do
    markup
    |> string_to_lines()
    |> Enum.map_join("\n", &String.trim/1)
  end

  def convert_markdown(markup) do
    markup
    |> prepare_content()
    |> Earmark.as_html(escape: false, smartypants: false)
    |> case do
      {:ok, html_doc, _messages} ->
        html_doc

      {:error, html_doc, _messages} ->
        html_doc
    end
  end

  def convert_haml(markup) do
    Calliope.render(markup)
  end

  def convert_markup(markup, "html"), do: markup
  def convert_markup(markup, "markdown"), do: convert_markdown(markup)
  def convert_markup(markup, "haml"), do: convert_haml(markup)

  def prepare_html(markup, format, html_processor)
      when is_binary(markup) and is_function(html_processor) do
    markup
    |> prepare_content()
    |> convert_markup(format)
    |> process_links()
    |> html_processor.()
  end

  def compile_template(id, template_source, format, html_processor \\ &Function.identity/1) do
    html =
      prepare_html(
        template_source,
        format,
        html_processor
      )

    if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.html", html)

    html
    |> TemplateParser.parse()
    |> TemplateCompiler.compile()
  end

  def compile_template_attribute(
        {_, %Attribute{name: name, type: :source_template, value: template_source}},
        node
      ) do
    format = NodeHelper.get_attr_value(node, "#{name}_format", "markdown")

    NodeHelper.set_compiled_template_attr(
      node,
      name,
      compile_template(node.id, template_source, format)
    )
  end

  def compile_template_attribute(_attribute, node) do
    node
  end

  def compile_template_attributes(node) do
    Enum.reduce(node.attributes, node, &compile_template_attribute/2)
  end
end
