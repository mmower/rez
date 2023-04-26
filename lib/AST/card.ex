defmodule Rez.AST.Card do
  @moduledoc """
  `Rez.AST.Card` defines the `Card` struct.

  A `Card` represents a unit of content specified as markup that contains
  also links representing the actions the player can take.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper
  alias Earmark
  alias Rez.AST.TemplateHelper

  defstruct status: :ok,
            game_element: true,
            id: nil,
            html: nil,
            template: nil,
            attributes: %{},
            position: {nil, 0, 0}

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

  @doc """
  Convert a target link in the form `[[Title|card_id]]` into a link which
  loads the relevant card or scene.

  ## Examples
      iex> import Rez.AST.Card
      iex> assert "<a href='javascript:void(0)' data-event='card' data-target='new_scene_id'>New Scene</a>" = convert_target_id_links("[[New Scene|new_scene_id]]")
  """
  def convert_target_id_links(text) do
    Regex.replace(~r/\[\[([\w\s]+)\|([\w\s]+)\]\]/U, text, fn _, target_text, target_id ->
      "<a href='javascript:void(0)' data-event='card' data-target='#{target_id}'>#{target_text}</a>"
    end)
  end

  @scene_shift_syntax ~r/\[\[([^|]*)\|\>\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

  @doc """
  Convert a link in the form `[[Title|><scene-id>]]` into a scene shift
  Handlebars helper call.
  """
  def convert_scene_shift_links(text) do
    Regex.replace(@scene_shift_syntax, text, fn _, title, scene_id ->
      "{{shift card '#{String.trim(scene_id)}' '#{String.trim(title)}'}}"
    end)
  end

  @scene_interlude_syntax ~r/\[\[([^|]*)\|!\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

  @doc """
  Convert a link in the form `[[Title|!<scene-id>]]` into a scene interlude
  Handlebars helper call.
  """
  def convert_scene_interlude_links(text) do
    Regex.replace(@scene_interlude_syntax, text, fn _, title, scene_id ->
      "{{interlude card '#{scene_id}' '#{title}'}}"
    end)
  end

  @scene_resume_syntax ~r/\[\[([^|]+)\|\s*!!\]\]/

  @doc """
  Converts a form `[[Link Text|!!]] into an invocation of the `r_resume` Handlebars helpers.
  """
  def convert_resume_links(text) do
    Regex.replace(@scene_resume_syntax, text, fn _, title ->
      "{{resume '#{title}'}}"
    end)
  end

  # Events are [[Title|*event_name]]
  # E.g. [[Save Game|*save]]
  # This will generate a link that will dispatch 'on_save' to the card
  @event_syntax ~r/\[\[([^|]+)\|\*\s*([_$a-zA-Z][_$a-zA-Z0-9]*)\]\]/

  def convert_event_links(text) do
    Regex.replace(@event_syntax, text, fn _, title, event_name ->
      "{{event '#{String.trim(title)}' '#{String.trim(event_name)}'}}"
    end)
  end

  @doc """
  Converts a link in the form [[*id]] into a dynamic link using a Handlebars custom
  helper function "dlink" that is part of the runtime. It is assumed that card will
  be available in the helper context. The 'action' is the name of a function attribute
  in the card that will control the dynamic link.

  See: Card.render() which always passes the current card into the bindings under
  the key 'card' which is referenced in the {{{dlink}}}

  Note that {{{}}} vs {{}} prevents escaping the returned HTML.
  """
  def convert_dynamic_links(text) do
    Regex.replace(~r/\[\[\*([\w\s]+)\]\]/, text, fn _, action ->
      "{{link card '#{action}'}}"
    end)
  end

  def process_links(original_html) do
    original_html
    |> convert_scene_shift_links()
    |> convert_scene_interlude_links()
    |> convert_resume_links()
    |> convert_target_name_links()
    |> convert_target_id_links()
    |> convert_event_links()
    |> convert_dynamic_links()
  end

  def build_template(%Card{id: card_id} = card) do
    TemplateHelper.make_template(
      card,
      "content",
      :template,
      fn html ->
        ~s(<div data-card="#{card_id}" class="card">) <>
          process_links(html) <>
          "</div>"
      end
    )
  end

  def build_template(%Card{id: card_id} = card, custom_css_class) do
    TemplateHelper.make_template(
      card,
      "content",
      :template,
      fn html ->
        ~s(<div data-card="#{card_id}" class="card #{custom_css_class}">) <>
          process_links(html) <>
          "</div>"
      end
    )
  end

  @doc ~S"""
  ## Examples
      iex> alias Rez.AST.{NodeHelper, Card}
      iex> Rez.Debug.start_link(0)
      iex> Rez.Handlebars.start_link("cache")
      iex> card = %Card{id: "test"} |> NodeHelper.set_string_attr("content", "This is **bold** text") |> Card.process()
      iex> assert %{
      ...>  status: :ok,
      ...>  template: "{\"compiler\":[8,\">= 4.3.0\"],\"main\":function(container,depth0,helpers,partials,data) {\n    return \"<div data-card=\\\"test\\\" class=\\\"card\\\"><p>\\nThis is <strong>bold</strong> text</p>\\n</div>\";\n},\"useData\":true}\n"
      ...> } = card
  """
  def process(%Card{status: :ok} = card) do
    case NodeHelper.get_attr_value(card, "css_class") do
      nil ->
        build_template(card)

      class ->
        build_template(card, class)
    end
  end

  def process(%Card{} = card) do
    card
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Card do
  import Rez.AST.NodeValidator
  alias Rez.AST.{Card, NodeHelper}

  def node_type(_card), do: "card"

  def js_ctor(card) do
    NodeHelper.get_attr_value(card, "js_ctor", "RezCard")
  end

  def default_attributes(_card), do: %{}

  def pre_process(card), do: card

  def process(%Card{} = card), do: Card.process(card)

  def children(_card), do: []

  def validators(_card) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      ),
      attribute_present?(
        "content",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "location",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("location")
        )
      ),
      attribute_if_present?(
        "blocks",
        attribute_has_type?(
          :list,
          attribute_coll_of?(
            :elem_ref,
            attribute_list_references?("card")
          )
        )
      ),
      attribute_if_present?(
        "css_clas",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "on_start",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_finish",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_render",
        attribute_has_type?(:function)
      )
    ]
  end
end
