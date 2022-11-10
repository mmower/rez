defmodule Rez.AST.ValueEncoder do
  @moduledoc """
  Functions for encoding attributes & their values in a form executable as
  JavaScript.
  """
  import Rez.Utils, only: [wrap_with: 3]

  @doc """
  Encode a map of attributes into a JS Object form
  """
  def encode_attributes(attributes) when is_map(attributes) do
    attributes
    |> Map.values()
    |> Enum.reject(&internal_attribute/1)
    |> Enum.map(&encode_attribute/1)
    |> Enum.into(%{})
    |> to_js_code()
  end

  @doc """
  Convert an Attribute struct into a tuple of the form {type, encoded-value}
  """
  def encode_attribute(%{type: type, name: name, value: value}) do
    {name, encode_value({type, value})}
  end

  def encode_value({type, value}) do
    case type do
      :number -> encode_number(value)
      :boolean -> encode_boolean(value)
      :dstring -> encode_dstring(value)
      :string -> encode_string(value)
      :keyword -> encode_keyword(value)
      :elem_ref -> encode_elem_ref(value)
      :attr_ref -> encode_attr_ref(value)
      :function -> encode_function(value)
      :roll -> encode_roll(value)
      :set -> encode_set(value)
      :list -> encode_list(value)
      :table -> encode_attributes(value)
      :btree -> encode_btree(value)
    end
  end

  defp encode_keyword(e) do
    "\"#{e}\""
  end

  defp encode_elem_ref(e) do
    "\"#{e}\""
  end

  defp encode_function({args, body}) do
    arg_list = Enum.join(args, ", ")
    "(#{arg_list}) => #{body}"
  end

  defp encode_number(n) do
    to_string(n)
  end

  @new_line_regex ~r/\n/
  @new_line_replacement "\\n"
  defp encode_newlines(s) do
    Regex.replace(@new_line_regex, s, @new_line_replacement)
  end

  @dquote_regex ~r/\"/
  @dquote_replacement "\\\""
  defp encode_dquotes(s) do
    Regex.replace(@dquote_regex, s, @dquote_replacement)
  end

  defp encode_dquotes_and_newlines(s) do
    s |> encode_newlines() |> encode_dquotes()
  end

  defp encode_string(s) do
    "\"" <> encode_dquotes_and_newlines(s) <> "\""
  end

  defp encode_dstring(s) do
    "`" <> encode_dquotes_and_newlines(s) <> "`"
  end

  defp encode_roll({count, sides, modifier}) do
    "new RezDie(#{count}, #{sides}, #{modifier})"
  end

  defp encode_attr_ref(name) do
    "{attr_ref: \"#{name}\"}"
  end

  defp encode_boolean(b) do
    to_string(b)
  end

  defp encode_list(lst) do
    lst
    |> Enum.map_join(", ", &encode_value/1)
    |> wrap_with("[", "]")
  end

  defp encode_set(set) do
    set
    |> MapSet.to_list()
    |> encode_list()
    |> then(fn encoded_list -> "new Set(" <> encoded_list <> ")" end)
  end

  def encode_btree({:node, behaviour_id, options, children}) when is_list(children) do
    child_nodes =
      children
      |> Enum.map(&encode_btree/1)
      |> Enum.join(", ")
      |> wrap_with("[", "]")

    ~s"""
    (function() {
      const behaviour_template = game.getGameObject("#{behaviour_id}");
      const options = #{encode_map(options)};
      return behaviour_template.instantiate(options, #{child_nodes});
    })()
    """
  end

  def encode_btree({:node, behaviour_id, options, []}) do
    ~s"""
    (function() {
      const behaviour_template = game.getGameObject("#{behaviour_id}");
      const options = #{encode_map(options)};
      return behaviour_template.instantiate(options);
    })()
    """
  end

  def encode_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, typed_value}, acc ->
      Map.put(acc, key, encode_value(typed_value))
    end) |> to_js_code()
  end

  @doc """
  Encode a Numberlist into a JS array
  """
  def encode_numberlist(lst) do
    lst
    |> Enum.map_join(", ", &to_string/1)
    |> wrap_with("[", "]")
  end

  @doc """
  Encode a Stringlist into a JS array
  """
  def encode_stringlist(lst) do
    lst
    |> Enum.map_join(", ", &encode_string/1)
    |> wrap_with("[", "]")
  end

  # Predicate for filtering attributes that should not be exposed to the JS
  # runtime.
  defp internal_attribute(%{name: name}) do
    String.starts_with?(name, "_")
  end

  @doc """
  js_encode converts an attribute into a representation suitable for inserting
  into Javascript code. Note that it more or less follows the rules for JSON
  encoding except we're not round-tripping via JSON and JSON doesn't natively
  support Javascript Functions.
  """
  def to_js_code(map) when is_map(map) do
    map
    |> Enum.map_join(",\n", fn {name, value} -> "\"#{name}\": #{value}" end)
    |> wrap_with("{", "}")
  end
end
