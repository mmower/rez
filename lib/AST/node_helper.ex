defmodule Rez.AST.NodeHelper do
  @moduledoc """
  `Rez.AST.NodeHelper` contains functions for working with the various
  AST node structures in the `Rez.AST` namespace. They are assumed to
  implement the `Rez.AST.Node` protocol.
  """
  alias Rez.AST.Attribute
  alias Rez.AST.Node
  import Rez.AST.ValueEncoder, only: [encode_attributes: 1]

  def has_id?(node) do
    Map.has_key?(node, :id)
  end

  def description(%{id: id, position: {file, line, col}} = node) when is_binary(file) do
    "#{Node.node_type(node)}/#{id} @ #{file}:#{line}:#{col}"
  end

  def description(%{position: {file, line, col}} = node) when is_binary(file) do
    "@#{Node.node_type(node)} @ #{file}:#{line}:#{col}"
  end

  def locator(%{position: {file, line, _}} = node) do
    {Node.node_type(node), file, line}
  end

  def get_attr(%{attributes: attributes} = _node, name)
      when is_binary(name) and is_map(attributes) do
    Map.get(attributes, name)
  end

  # I wonder if there is a way to do this via pattern matching as
  # get_attr_value(%{attributes: %{^name: %{value: value}}}, name), do: value
  # doesn't work though
  def get_attr_value(%{attributes: attributes} = _object, name, default \\ nil)
      when not is_nil(attributes) and is_binary(name) do
    case Map.get(attributes, name) do
      nil ->
        default

      attribute ->
        Map.get(attribute, :value)
    end
  end

  def has_attr?(%{attributes: attributes}, name) when is_binary(name) do
    Map.has_key?(attributes, name)
  end

  def set_attr(%{attributes: attributes} = node, %Attribute{name: name} = attr) do
    %{node | attributes: Map.put(attributes, name, attr)}
  end

  def set_default_attr_value(%{attributes: _attributes} = node, name, value, setter)
      when is_binary(name) and is_function(setter) do
    case has_attr?(node, name) do
      true ->
        node

      false ->
        setter.(node, name, value)
    end
  end

  def set_attr_value(node, name, {:boolean, value}) when is_boolean(value) do
    set_boolean_attr(node, name, value)
  end

  def set_attr_value(node, name, {:string, value}) when is_binary(value) do
    set_string_attr(node, name, value)
  end

  def set_attr_value(node, name, {:number, value}) when is_number(value) do
    set_number_attr(node, name, value)
  end

  def set_attr_value(node, name, {:elem_ref, value}) when is_binary(value) do
    set_elem_ref_attr(node, name, value)
  end

  def set_attr_value(node, name, {:keyword, value}) when is_binary(value) do
    set_keyword_attr(node, name, value)
  end

  def set_attr_value(node, name, {:list, value}) when is_list(value) do
    set_list_attr(node, name, value)
  end

  def set_attr_value(node, name, {:function, {:std, params, body}}) do
    set_std_func_attr(node, name, {params, body})
  end

  def set_attr_value(node, name, {:function, {:arrow, params, body}}) do
    set_arrow_func_attr(node, name, {params, body})
  end

  def set_attr_value(node, name, {:set, value}) do
    set_set_attr(node, name, value)
  end

  def set_attr_value(node, name, {:table, value}) do
    set_table_attr(node, name, value)
  end

  def set_attr_value(node, name, {:compiled_template, value}) do
    set_compiled_template_attr(node, name, value)
  end

  def set_attr_value(node, name, {:bht, value}) do
    set_bht_attr(node, name, value)
  end

  def set_attr_value(node, name, {:placeholder, _}) do
    set_placeholder_attr(node, name)
  end

  def set_boolean_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_boolean(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.boolean(name, value))}
  end

  def set_string_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.string(name, value))}
  end

  def set_elem_ref_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.elem_ref(name, value))}
  end

  def set_keyword_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_binary(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.keyword(name, value))}
  end

  def set_list_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_list(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.list(name, value))}
  end

  def set_std_func_attr(%{attributes: attributes} = node, name, {params, body})
      when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.std_function(name, {params, body}))}
  end

  def set_arrow_func_attr(%{attributes: attributes} = node, name, {params, body})
      when is_binary(name) do
    %{
      node
      | attributes: Map.put(attributes, name, Attribute.arrow_function(name, {params, body}))
    }
  end

  def set_set_attr(%{attributes: attributes} = node, name, values) when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.set(name, values))}
  end

  def set_table_attr(%{attributes: attributes} = node, name, %{} = values) when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.table(name, values))}
  end

  def set_number_attr(%{attributes: attributes} = node, name, value)
      when is_binary(name) and is_number(value) do
    %{node | attributes: Map.put(attributes, name, Attribute.number(name, value))}
  end

  def set_compiled_template_attr(
        %{attributes: attributes} = node,
        name,
        {:compiled_template, t}
      )
      when is_binary(name) do
    %{node | attributes: Map.put(attributes, name, Attribute.compiled_template(name, t))}
  end

  def set_bht_attr(%{attributes: attributes} = node, name, {:bht, value}) do
    %{node | attributes: Map.put(attributes, name, Attribute.bht(name, value))}
  end

  def set_placeholder_attr(%{attributes: attributes} = node, name) do
    %{node | attributes: Map.put(attributes, name, Attribute.placeholder(name))}
  end

  def delete_attr(%{attributes: attributes} = node, name) when is_binary(name) do
    %{node | attributes: Map.delete(attributes, name)}
  end

  def template_node?(node), do: get_attr_value(node, "$template", false)
  def instance_node?(node), do: !template_node?(node)

  def inspect_value({:keyword, value}) do
    ":#{value}"
  end

  def inspect_value({:string, value}) do
    value
  end

  def inspect_value({:number, value}) do
    to_string(value)
  end

  def inspect_value({:boolean, value}) do
    to_string(value)
  end

  def inspect_value({:elem_ref, value}) do
    "##{value}"
  end

  def inspect_value(:placeholder) do
    "placeholder"
  end

  def inspect_value({_, value}) do
    inspect(value)
  end

  def build_type_map(nodes) when is_list(nodes) do
    nodes
    |> Enum.group_by(&Node.node_type/1)
    |> Map.update!("game", fn [game] -> game end)
  end

  def build_id_map(nodes) when is_list(nodes) do
    nodes
    |> Enum.filter(&Map.has_key?(&1, :id))
    |> Enum.reduce(%{}, fn %{id: id} = node, map ->
      Map.put(map, id, node)
    end)
  end

  def first_elem(nodes, struct_module) do
    filter_elem(nodes, struct_module) |> List.first()
  end

  def filter_elem(nodes, struct_module) when is_atom(struct_module) do
    Enum.filter(nodes, fn node -> is_struct(node, struct_module) end)
  end

  def extract_nodes(nodes, struct_module) when is_atom(struct_module) do
    Enum.split_with(nodes, fn node -> is_struct(node, struct_module) end)
  end

  @doc """
  Returns {game_element, game_elements, auxilliary_elements}
  """
  def partition_elements(nodes) do
    {game_elements, aux_elements} = Enum.split_with(nodes, & &1.game_element)
    {[game_element], game_elements} = Enum.split_with(game_elements, &is_struct(&1, Rez.AST.Game))
    {game_element, game_elements, aux_elements}
  end

  def reject_templates(nodes) do
    Enum.filter(nodes, fn node -> instance_node?(node) end)
  end

  def get_meta(%{metadata: metadata}, meta_name, default \\ nil) do
    Map.get(metadata, meta_name, default)
  end

  def set_meta(%{metadata: metadata} = node, meta_name, value) do
    %{node | metadata: Map.put(metadata, meta_name, value)}
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
    |> then(&"Elixir.Rez.AST.#{&1}")
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
  Given a node, search for behaviour-tree attributes and expand any templates used in the tree
  """
  def expand_behaviour_templates(node, templates) do
    Enum.reduce(node.attributes, node, fn
      {_, %{type: :bht} = attr}, node ->
        expand_behaviour_attribute(node, attr, templates)

      _, node ->
        node
    end)
  end

  @doc """
  Given a behaviour-tree attribute, expand any templates within the value
  """
  def expand_behaviour_attribute(node, %{name: name, value: root_behaviour}, templates) do
    set_bht_attr(node, name, {:bht, expand_behaviour(root_behaviour, templates)})
  end

  def expand_behaviour({:template, template_id}, templates) do
    case Map.get(templates, template_id) do
      nil ->
        IO.puts("Compiler error: No @behaviour_template with id: '#{template_id}'!")
        System.halt(98)

      tmpl ->
        expand_behaviour(tmpl, templates)
    end
  end

  def expand_behaviour({behaviour_id, options, children}, templates) do
    {behaviour_id, options, Enum.map(children, &expand_behaviour(&1, templates))}
  end

  # Default implementations of Node protocol methods for defdelegate

  def js_initializer(node) do
    ~s"""
    new #{Node.js_ctor(node)}(
      "#{node.id}",
      #{encode_attributes(node.attributes)}
    )
    """
  end

  def html_processor(_node, _attr) do
    &Function.identity/1
  end
end
