defmodule Rez.AST.TemplateHelper do
  alias Rez.AST.NodeHelper
  alias Rez.{Debug, Handlebars}
  import Rez.Utils

  defp prepare_content(%{} = node, source_attr) do
    node
    |> NodeHelper.get_attr_value(source_attr)
    |> string_to_lines()
    |> Enum.map_join("\n", &String.trim/1)
  end

  @intermediate_key "_auto_html"

  defp convert_markdown(%{} = node, source_attr, html_processor) do
    node
    |> prepare_content(source_attr)
    |> Earmark.as_html(escape: false, smartypants: false)
    |> case do
      {:ok, html, _} ->
        node
        |> Map.put(@intermediate_key, html_processor.(html))
        |> NodeHelper.delete_attr(source_attr)

      {:error, _, errors} ->
        %{node | status: {:error, errors}}
    end
  end

  defp compile_template(%{status: :ok} = node, target_key, label) do
    html = Map.get(node, @intermediate_key)

    case Handlebars.compile(html, label) do
      {:ok, template} ->
        node
        |> Map.put(target_key, template)
        |> Map.delete(@intermediate_key)

      {:error, reason} ->
        %{node | status: {:error, reason}}
    end
  end

  defp compile_template(%{} = node, _target_key, _label) do
    node
  end

  def log_html(%{id: id} = node) do
    if Debug.dbg_do?(:debug) do
      html = Map.get(node, @intermediate_key)
      File.write!("cache/#{id}.html", html)
    end

    node
  end

  def make_template(%{} = node, source_attr, target_key, html_processor) when is_function(html_processor) do
    case NodeHelper.has_attr?(node, source_attr) do
      false ->
        node

      true ->
        node
        |> convert_markdown(source_attr, html_processor)
        |> log_html()
        |> compile_template(target_key, "#{node.id}/#{source_attr}")
    end
  end
end
