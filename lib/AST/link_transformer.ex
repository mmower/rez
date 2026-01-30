defmodule Rez.AST.LinkTransformer do
  @moduledoc """
  Documentation for `LinkTransformer`.
  """

  def transform(html) when is_binary(html) do
    html
    |> transform_a_tags()
    |> transform_button_tags()
  end

  @doc """
  Transforms the given HTML doing the following transformations to <a> tags:

  - leaves existing href alone
  - where there is no href attribute, adds href="javascript:void(0)"
  - where there is a card="card-id" attribute, replaces it with data-event="card" and data-target="card-id"
  - where there is a scene="scene-id" attribute, replaces it with data-event="scene" and data-target="scene-id"
  - where there is an interlude="scene-id" attribute, replaces it with data-event="interlude" and data-target="scene-id"
  - where there is a resume attribute, replaces it with data-event="resume"
  - where there is an event="handler" attribute, replaces it with data-event="handler"
  """
  def transform_a_tags(html) do
    # Split the HTML into parts based on <a> tags
    parts = String.split(html, ~r{(<a\s[^>]*>|<a>|</a>)}, include_captures: true)

    # Process each part
    Enum.map_join(parts, "", fn part ->
      case part do
        "<a" <> _rest -> transform_opening_tag(:a, part)
        _ -> part
      end
    end)
  end

  def transform_button_tags(html) do
    parts =
      String.split(html, ~r{(<button(?:\s[^>]*)?>|</button>)}, include_captures: true)

    # Process each part
    Enum.map_join(parts, "", fn part ->
      case part do
        "<button" <> _rest -> transform_opening_tag(:button, part)
        _ -> part
      end
    end)
  end

  defp transform_opening_tag(:a, tag) do
    tag
    |> add_default_href()
    |> transform_event_attribute()
    |> transform_card_attribute()
    |> transform_scene_attribute()
    |> transform_interlude_attribute()
    |> transform_resume_attribute()
  end

  defp transform_opening_tag(:button, tag) do
    tag
    |> transform_event_attribute()
    |> transform_card_attribute()
    |> transform_scene_attribute()
    |> transform_interlude_attribute()
    |> transform_resume_attribute()
  end

  defp add_default_href(tag) do
    if String.match?(tag, ~r/href=/i) do
      tag
    else
      String.replace(tag, ~r/>$/, " href=\"javascript:void(0)\">")
    end
  end

  defp transform_card_attribute(tag) do
    Regex.replace(~r/(?<=\s)card="([^"]*)"/, tag, "data-event=\"card\" data-target=\"\\1\"")
  end

  defp transform_scene_attribute(tag) do
    Regex.replace(~r/(?<=\s)scene="([^"]*)"/, tag, "data-event=\"switch\" data-target=\"\\1\"")
  end

  defp transform_interlude_attribute(tag) do
    Regex.replace(~r/(?<=\s)interlude="([^"]*)"/, tag, "data-event=\"interlude\" data-target=\"\\1\"")
  end

  defp transform_resume_attribute(tag) do
    Regex.replace(~r/(?<=\s)resume(?:="[^"]*")?/, tag, "data-event=\"resume\"")
  end

  defp transform_event_attribute(tag) do
    Regex.replace(~r/(?<=\s)event="([^"]*)"/, tag, "data-event=\"\\1\"")
  end
end
