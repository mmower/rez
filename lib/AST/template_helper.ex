defmodule Rez.AST.TemplateHelper do
  @moduledoc """
  Tools to convert attributes representing templates into Rez pre-compiled
  template expression functions.
  """
  alias Rez.Debug
  import Rez.Utils

  alias Rez.AST.Attribute
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.AST.HtmlTransformer

  alias Rez.Compiler.TemplateCompiler
  alias Rez.Parser.TemplateParser

  def prepare_content(markup) when is_binary(markup) do
    markup
    |> HtmlTransformer.transform()
    |> string_to_lines()
    |> Enum.map_join("\n", &String.trim/1)
  end

  def ready_template(id, template_source, html_processor) do
    template_source
    |> then(fn src ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.src", src)
      src
    end)
    |> prepare_content()
    |> then(fn src ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.prepared", src)
      src
    end)
    |> html_processor.()
    |> then(fn html ->
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.html", html)
      html
    end)
    |> TemplateParser.parse()
  end

  def compile_template(id, template_source, html_processor \\ &Function.identity/1) do
    with {:ok, template} <- wrap_template_result(ready_template(id, template_source, html_processor)),
         {:ok, compiled} <- wrap_compile_result(TemplateCompiler.compile(template)) do
      {:compiled_template, js} = compiled
      if Debug.dbg_do?(:debug), do: File.write!("cache/#{id}.js", js)
      compiled
    end
  end

  defp wrap_template_result({:error, _} = error), do: error
  defp wrap_template_result(template), do: {:ok, template}

  defp wrap_compile_result({:error, _} = error), do: error
  defp wrap_compile_result({:compiled_template, _} = compiled), do: {:ok, compiled}

  @doc """
  The compile_template_attribute/2 function compiles a :source_template into a
  JS rendering function using TemplateCompiler.compile_template. It creates a
  new attribute using a naming pattern:

  "$" <> source_attr_name <> "_template"

  so

  layout -> $layout_template
  """
  def compile_template_attribute(
        {_, %Attribute{name: name, type: :source_template, value: template_source}},
        node
      ) do
    case compile_template(node.id, template_source, Node.html_processor(node, name)) do
      {:error, errors} ->
        add_template_errors(node, name, errors)
        |> NodeHelper.delete_attr(name)

      compiled_template ->
        node
        |> NodeHelper.set_compiled_template_attr("$#{name}_template", compiled_template)
        |> NodeHelper.delete_attr(name)
    end
  end

  def compile_template_attribute(_attribute, node) do
    node
  end

  def compile_template_attributes(node) do
    Enum.reduce(node.attributes, node, &compile_template_attribute/2)
  end

  defp add_template_errors(node, name, errors) when is_list(errors) do
    Enum.reduce(errors, node, fn {error_type, {line, col}, message}, acc ->
      NodeHelper.add_error(acc, "#{name}:#{line}:#{col} #{error_type}: #{message}")
    end)
  end

  defp add_template_errors(node, name, error) when is_binary(error) do
    NodeHelper.add_error(node, "#{name}: #{error}")
  end
end
