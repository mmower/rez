defmodule Rez.AST.HtmlTransformer do
  def transform(html) do
    case Floki.parse_fragment(html) do
      {:ok, tree} ->
        tree
        |> Floki.traverse_and_update(&transform_tag/1)
        |> Floki.raw_html(encode: false)

      _ ->
        html
    end
  end

  def transform_tag({"a", attrs, content}) do
    {"a", transform_attrs(attrs), content}
  end

  def transform_tag(tag_node) do
    tag_node
  end

  def transform_attrs(attrs) do
    attrs
    |> transform_card_attr()
    |> transform_scene_change_attr()
    |> transform_scene_interlude_attr()
    |> transform_scene_resume_attr()
    |> insert_href_attr()
  end

  def insert_href_attr(attrs) do
    attr_insert(attrs, {"href", "javascript:void(0);"})
  end

  def transform_card_attr(attrs) do
    case attr_value(attrs, "card") do
      nil ->
        attrs

      card_id ->
        attrs
        |> attr_delete({"card", card_id})
        |> attr_insert({"data-target", card_id})
        |> attr_insert({"data-event", "card"})
    end
  end

  def transform_scene_change_attr(attrs) do
    case attr_value(attrs, "scene") do
      nil ->
        attrs

      scene_id ->
        attrs
        |> attr_delete({"scene", scene_id})
        |> attr_insert({"data-target", scene_id})
        |> attr_insert({"data-event", "switch"})
    end
  end

  def transform_scene_interlude_attr(attrs) do
    case attr_value(attrs, "interlude") do
      nil ->
        attrs

      scene_id ->
        attrs
        |> attr_delete({"interlude", scene_id})
        |> attr_insert({"data-target", scene_id})
        |> attr_insert({"data-event", "interlude"})
    end
  end

  def transform_scene_resume_attr(attrs) do
    case attr_value(attrs, "resume") do
      nil ->
        attrs

      _ ->
        attrs
        |> attr_delete({"resume", "resume"})
        |> attr_insert({"data-event", "resume"})
    end
  end

  def attr_value(attrs, attr_name) do
    with {_name, value} <- List.keyfind(attrs, attr_name, 0) do
      value
    end
  end

  def attr_delete(attrs, {_attr_name, _attr_value} = attr) do
    List.delete(attrs, attr)
  end

  def attr_insert(attrs, {_attr_name, _attr_value} = attr) do
    List.insert_at(attrs, 0, attr)
  end
end
