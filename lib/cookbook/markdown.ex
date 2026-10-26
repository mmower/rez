defmodule Rez.Cookbook.Markdown do
  @moduledoc """
  `Rez.Cookbook.Markdown` converts cookbook module documentation from Markdown
  to HTML.

  Parsing is done by `EarmarkParser` which returns an AST of
  `{tag, attrs, children, meta}` nodes that we render to HTML ourselves.

  Text nodes are HTML-escaped (existing `&#x...;` entities are left alone)
  except inside nodes the parser marks as `verbatim`, i.e. raw HTML blocks,
  which are passed through untouched.
  """

  # https://html.spec.whatwg.org/multipage/syntax.html#void-elements
  @void_elements ~w(area base br col embed hr img input link meta source track wbr)

  # Elements that must not be followed by a newline as it would add whitespace to the text
  @inline_elements ~w(a abbr b br code del em i img kbd mark s small span strong sub sup)

  # Elements whose children are themselves elements, so start them on a new line
  @container_elements ~w(blockquote ol table tbody thead tr ul)

  @doc """
  Converts a Markdown string into a standalone HTML page.
  """
  def to_html_page(markdown) do
    markdown
    |> to_html()
    |> wrap_html()
  end

  @doc """
  Converts a Markdown string into an HTML fragment.
  """
  def to_html(markdown) do
    {_status, ast, _messages} = EarmarkParser.as_ast(markdown, footnotes: true)

    ast
    |> render(false)
    |> IO.iodata_to_binary()
  end

  defp render(nodes, verbatim) when is_list(nodes) do
    Enum.map(nodes, &render(&1, verbatim))
  end

  defp render(text, false) when is_binary(text), do: escape(text)
  defp render(text, true) when is_binary(text), do: text

  defp render({:comment, _attrs, lines, _meta}, _verbatim) do
    ["<!--", Enum.intersperse(lines, ?\n), "-->\n"]
  end

  defp render({tag, attrs, _children, _meta}, _verbatim) when tag in @void_elements do
    [open_tag(tag, attrs), newline(tag)]
  end

  defp render({tag, attrs, children, meta}, _verbatim) do
    verbatim = Map.get(meta, :verbatim, false)

    [
      open_tag(tag, attrs),
      if(tag in @container_elements, do: ?\n, else: []),
      render(children, verbatim),
      "</",
      tag,
      ">",
      newline(tag)
    ]
  end

  defp newline(tag) when tag in @inline_elements, do: []
  defp newline(_tag), do: ?\n

  defp open_tag(tag, attrs) do
    ["<", tag, Enum.map(attrs, &render_attr/1), ">"]
  end

  defp render_attr({name, value}) do
    [" ", name, "=\"", escape(value), "\""]
  end

  defp escape(text) do
    text
    |> String.split(~r/&#x[0-9a-fA-F]+;/, include_captures: true)
    |> Enum.map(fn
      "&#x" <> _ = entity -> entity
      chunk -> escape_chunk(chunk)
    end)
  end

  defp escape_chunk(chunk) do
    for <<char <- chunk>>, into: "" do
      case char do
        ?< -> "&lt;"
        ?> -> "&gt;"
        ?& -> "&amp;"
        ?" -> "&quot;"
        ?' -> "&#39;"
        _ -> <<char>>
      end
    end
  end

  defp wrap_html(body) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #333; }
        pre { background: #f5f5f5; padding: 1rem; border-radius: 4px; overflow-x: auto; }
        code { background: #f5f5f5; padding: 0.2em 0.4em; border-radius: 3px; font-size: 0.9em; }
        pre code { background: none; padding: 0; }
        img { max-width: 100%; }
        h1, h2, h3 { color: #222; }
      </style>
    </head>
    <body>
    #{body}
    </body>
    </html>
    """
  end
end
