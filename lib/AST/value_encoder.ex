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

  def encode_value({:placeholder, _}) do
    # "_placeHolderValue"
    ~s|""|
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

  def encode_value({:list_binding, {prefix, deref, {:literal, value}}}) when is_boolean(deref) do
    ~s|{prefix: "#{prefix}", deref: #{deref}, literal: #{encode_value(value)}}|
  end

  def encode_value({:list_binding, {prefix, {:literal, value}}}) do
    ~s|{prefix: "#{prefix}", literal: #{encode_value(value)}}|
  end

  def encode_value({:list_binding, {prefix, {:source, deref, value}}}) when is_boolean(deref) do
    ~s|{prefix: "#{prefix}", deref: #{deref}, source: #{encode_value(value)}}|
  end

  def encode_value({:bound_path, path}) do
    js_path =
      "[" <> Enum.map_join(path, ", ", fn path_component -> ~s|"#{path_component}"| end) <> "]"

    ~s|{binding: (root) => {
      return #{js_path}.reduce((obj, path_component) => {
        return obj[path_component]}, root);
      }
    }|
  end

  def encode_value({:dynamic_initializer, {initializer, prio}}) do
    "{initializer: #{Poison.encode!(initializer)}, priority: #{prio}}"
  end

  def encode_value({:copy_initializer, {elem_id, prio}}) do
    "{$copy: #{encode_value({:elem_ref, elem_id})}, priority: #{prio}}"
  end

  def encode_value({:delegate, attr_name}) do
    ~s|{$delegate: "#{attr_name}"}|
  end

  def encode_value({:property, f}) do
    "{property: #{Poison.encode!(f)}}"
  end

  def encode_value({:ptable, pairs}) do
    total = Enum.map(pairs, fn {_value, freq} -> freq end) |> Enum.sum()

    {_, entries} =
      Enum.reduce(pairs, {0, []}, fn {value, freq}, {last_p, entries} ->
        p = freq / total + last_p
        {p, [{:list, [value, {:number, p}]} | entries]}
      end)

    entries =
      entries
      |> Enum.reverse()
      |> encode_list()

    "{ptable: #{Poison.encode!(entries)}}"
  end

  def encode_value({:elem_ref, r}) do
    ~s|{$ref: "#{r}"}|
  end

  def encode_value({:function, f}) do
    encode_function(f)
  end

  def encode_value({:code_block, code}) do
    "function(obj) {return (#{code});}"
  end

  def encode_value({:roll, {count, sides, modifier, rounds}}) do
    "new RezDieRoll(#{count}, #{sides}, #{modifier}, #{rounds})"
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

  def encode_value({:bht, t}) do
    ~s|{bht: #{encode_bht(t)}}|
  end

  def encode_value({:table, t}) do
    encode_attributes(t)
  end

  @doc """
  The template `t` is a function(bindings, filters) that returns the content
  of the template. A challenge is that the 'this' binding is undefined for
  some reason (it's not even 'Window') and so we cannot supply a context.
  """
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

  def encode_bht({behaviour_id, options, children}) when is_map(options) and is_list(children) do
    child_nodes =
      children
      |> Enum.map_join(", ", &encode_bht/1)
      |> wrap_with("[", "]")

    ~s|{behaviour: "#{behaviour_id}", options: #{encode_map(options)}, children: #{child_nodes}}|
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
