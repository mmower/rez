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
    |> Enum.reject(&internal_attribute?/1)
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

  def encode_value({:number, n}) do
    to_string(n)
  end

  def encode_value({:boolean, b}) do
    to_string(b)
  end

  def encode_value({:string, s}) do
    ~s|"#{encode_dquotes_and_newlines(s)}"|
  end

  def encode_value({:dstring, s}) do
    "`" <> encode_dquotes_and_newlines(s) <> "`"
  end

  def encode_value({:keyword, k}) do
    ~s|"#{k}"|
  end

  def encode_value({:dynamic_initializer, i}) do
    "{initializer: #{Poison.encode!(i)}}"
  end

  def encode_value({:elem_ref, r}) do
    ~s|"#{r}"|
  end

  def encode_value({:function, f}) do
    encode_function(f)
  end

  def encode_value({:roll, {count, sides, modifier, rounds}}) do
    "new RezDie(#{count}, #{sides}, #{modifier}, #{rounds})"
  end

  def encode_value({:list, l}) do
    encode_list(l)
  end

  def encode_value({:set, s}) do
    s
    |> MapSet.to_list()
    |> encode_list()
    |> then(fn encoded_list -> "new Set(" <> encoded_list <> ")" end)
  end

  def encode_value({:btree, t}) do
    encode_btree(t)
  end

  def encode_value({:table, t}) do
    encode_attributes(t)
  end

  def encode_value({:compiled_template, t}) do
    t
  end

  defp encode_list(l) do
    l
    |> Enum.map_join(", ", &encode_value/1)
    |> wrap_with("[", "]")
  end

  def encode_function({:std, args, body}) do
    arg_list = Enum.join(args, ", ")
    "function(#{arg_list}) #{body}"
  end

  def encode_function({:arrow, args, body}) do
    arg_list = Enum.join(args, ", ")
    "(#{arg_list}) => #{body}"
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

  def encode_btree([]) do
    "[]"
  end

  def encode_btree({:node, behaviour_id, options, children}) when is_list(children) do
    child_nodes =
      children
      |> Enum.map_join(", ", &encode_btree/1)
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
    end)
    |> to_js_code()
  end

  # Predicate for filtering attributes that should not be exposed to the JS
  # runtime.
  defp internal_attribute?(%{name: name}) do
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
