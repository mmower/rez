defmodule Rez.AST.NodeHelper do
  @moduledoc """
  `Rez.AST.NodeHelper` contains functions for working with the various
  AST node structures in the `Rez.AST` namespace. They are assumed to
  implement the `Rez.AST.Node` protocol.
  """
  import Rez.Utils, only: [map_to_map: 2]
  alias Rez.AST.Attribute
  alias Rez.AST.Node
  import Rez.AST.ValueEncoder, only: [encode_attributes: 1]

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

  def delete_attr(%{attributes: attributes} = node, name) when is_binary(name) do
    %{node | attributes: Map.delete(attributes, name)}
  end

  def is_template?(node), do: get_attr_value(node, "$template", false)

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
  This is called from the compiler before other processing happens, we delegate
  to the nodes themselves for node-specific pre-processing steps.
  """
  def pre_process(node) do
    node
    |> Node.pre_process()
  end

  @doc """
  Given a Node with a collection of Nodes under `coll_key` return a new Node
  with the collection under `coll_key` having been passed through
  `Node.process` themselves.
  """
  def process_collection(parent, coll_key, node_map) do
    case Map.get(parent, coll_key) do
      nil ->
        parent

      coll ->
        Map.put(
          parent,
          coll_key,
          map_to_map(coll, fn child_node ->
            Node.process(child_node, node_map)
          end)
        )
    end
  end

  @doc """
  `copy_attributes/2` looks at each parent defined for the node and where the
  node doesn't define an attribute that is defined in the parent, copies it
  into the child.
  """
  def copy_attributes(node, node_map) do
    case get_attr_value(node, "_parents", []) do
      [] ->
        node

      parents ->
        parents
        |> Enum.reduce(node, fn {:keyword, parent_id}, node ->
          case Map.get(node_map, to_string(parent_id)) do
            nil ->
              IO.puts("Cannot find claimed parent #{parent_id} of #{node.id}!")
              node

            parent ->
              copy_attributes_from_parent(node, parent)
          end

          copy_attributes_from_parent(node, Map.get(node_map, to_string(parent_id)))
        end)
    end
  end

  def copy_attributes_from_parent(node, parent) do
    Enum.reduce(parent.attributes, node, fn {_, attribute}, node ->
      cond do
        String.starts_with?(attribute.name, "_") ->
          node

        has_attr?(node, attribute.name) ->
          node

        true ->
          set_attr(node, attribute)
      end
    end)
  end

  defp is_virtual_parent?(node_map, {:keyword, parent_id}) do
    case Map.get(node_map, parent_id) do
      nil ->
        false

      parent ->
        get_attr_value(parent, "_virtual", false)
    end
  end

  @doc """
  Virtual elements (typically used in @alias's) do not actually get turned into
  gametime objects and, therefore, do not get initialized. We shouldn't consider
  them after their attributes have been copied over.
  """
  def remove_virtual_parents(node, node_map) do
    case get_attr(node, "_parents") do
      nil ->
        node

      %Attribute{value: parent_ids} = attr ->
        set_attr(node, %{
          attr
          | value: Enum.filter(parent_ids, &(!is_virtual_parent?(node_map, &1)))
        })
    end
  end

  def js_initializer(node) do
    ~s"""
    new #{Node.js_ctor(node)}(
      "#{node.id}",
      #{encode_attributes(node.attributes)}
    )
    """
  end
end
