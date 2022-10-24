defmodule Rez.AST.NodeHelper do
  @moduledoc """
  `Rez.AST.NodeHelper` contains functions for working with the various
  AST node structures in the `Rez.AST` namespace. They are assumed to
  implement the `Rez.AST.Node` protocol.
  """
  import Rez.Utils, only: [wrap_with: 3, map_to_map: 2]
  alias Rez.AST.{Attribute, Node}

  def description(%{id: id, position: {file, line, col}} = node) when is_binary(file) do
    "#{Node.node_type(node)}/#{id} @ #{file}:#{line}:#{col}"
  end

  def description(%{position: {file, line, col}} = node) when is_binary(file) do
    "@#{Node.node_type(node)} @ #{file}:#{line}:#{col}"
  end

  def locator(%{position: {file, line, _}} = node) do
    {Node.node_type(node), file, line}
  end

  def get_attr(%{attributes: attributes} = _node, name) when is_binary(name) do
    Map.get(attributes, name)
  end

  # I wonder if there is a way to do this via pattern matching as
  # get_attr_value(%{attributes: %{^name: %{value: value}}}, name), do: value
  # doesn't work though
  def get_attr_value(%{attributes: attributes} = _object, name) when not is_nil(attributes) and is_binary(name) do
    case Map.get(attributes, name) do
      nil -> nil
      attribute -> Map.get(attribute, :value)
    end
  end

  def has_attr?(%{attributes: attributes}, name) when is_binary(name) do
    Map.has_key?(attributes, name)
  end

  def set_default_attr_value(%{attributes: _attributes} = node, name, value, setter) when is_binary(name) and is_function(setter) do
    case has_attr?(node, name) do
      true ->
        node

      false ->
        setter.(node, name, value)
    end
  end

  def set_boolean_attr(%{attributes: attributes} = node, name, value) when is_binary(name) and is_boolean(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.boolean(name, value))}
  end

  def set_string_attr(%{attributes: attributes} = node, name, value) when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.string(name, value))}
  end

  def set_elem_ref_attr(%{attributes: attributes} = node, name, value) when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.elem_ref(name, value))}
  end

  def set_keyword_attr(%{attributes: attributes} = node, name, value) when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.keyword(name, value))}
  end

  def set_func_attr(%{attributes: attributes} = node, name, {params, body}) when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.function(name, {params, body}))}
  end

  def set_set_attr(%{attributes: attributes} = node, name, values) when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.set(name, values))}
  end

  def set_number_attr(%{attributes: attributes} = node, name, value) when is_binary(name) and is_number(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.number(name, value))}
  end

  def delete_attr(%{attributes: attributes} = node, name) when is_binary(name) do
    %{node | attributes: Map.delete(attributes, name)}
  end

  @doc """
  Returns the Node struct for a given tag name.

  While this can be done dynamically using `String.to_existing_atom` this allows
  us to have more control over which modules are directly available.

  Returns a module.
  """
  def node_for_tag(tag) do
    tag
    |> String.capitalize()
    |> then(&("Elixir.Rez.AST.#{&1}"))
    |> String.to_existing_atom()
  end

  @doc """
  Returns true or false based on whether there is a Node struct for a given
  tag name
  """
  def tag_defined?(tag) do
    try do
      node_for_tag(tag)
      true
    rescue
      ArgumentError -> false
    end
  end

  @doc """
  Pre-pend an error to the Node struct error list and set its status to :error
  """
  def add_error(%{status: :ok} = node, error) do
    %{node | status: {:error, [error]}}
  end

  def add_error(%{status: {:error, errors}} = node, error) when is_list(errors) do
    %{node | status: {:error, [error | errors]}}
  end

  @doc """
  Given a Node with a collection of Nodes under `coll_key` return a new Node
  with the collection under `coll_key` having been passed through
  `Node.process` themselves.
  """
  def process_collection(parent, coll_key) do
    case Map.get(parent, coll_key) do
      nil -> parent
      coll -> Map.put(parent, coll_key, map_to_map(coll, &Node.process/1))
    end
  end

  @doc """
  Convert an Attribute struct into a tuple of the form {type, encoded-value}
  """
  def encode_attribute(%{type: type, name: name, value: value}) do
    {name, encode_value({type, value})}
  end

  defp encode_value({type, value}) do
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
