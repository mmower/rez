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

  @a_regex ~r/(<a)((?![^>]*\shref)[^>]*\sdata-event\s*=[^>]*>)/

  def insert_hrefs(markup) do
    Regex.replace(@a_regex, markup, fn _match, c1, c2 ->
      c1 <> ~s| href="javascript:void(0)"| <> c2
    end)
  end

  def prepare_content(markup) when is_binary(markup) do
    markup
    |> insert_hrefs()
    |> string_to_lines()
    |> Enum.map_join("\n", &String.trim/1)
  end

  def compile_template(id, template_source, html_processor \\ &Function.identity/1) do
    template_source
    |> then(fn src ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.src", src)
      src
    end)
    |> prepare_content()
    |> html_processor.()
    |> then(fn html ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.html", html)
      html
    end)
    |> TemplateParser.parse()
    |> TemplateCompiler.compile()
    |> then(fn {:compiled_template, js} = template ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.js", js)
      template
    end)
  end

  def compile_template_attribute(
        {_, %Attribute{name: name, type: :source_template, value: template_source}},
        node
      ) do
    NodeHelper.set_compiled_template_attr(
      node,
      name,
      compile_template(node.id, template_source)
    )
  end

  def compile_template_attribute(_attribute, node) do
    node
  end

  def compile_template_attributes(node) do
    Enum.reduce(node.attributes, node, &compile_template_attribute/2)
  end
end
