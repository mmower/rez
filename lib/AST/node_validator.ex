defmodule Rez.AST.NodeValidator do
  @moduledoc """
  `Rez.AST.NodeValidator` defines the `Validation` struct and contains
  functions for validating child nodes and attribute presence/value and so on.
  """

  defmodule Validation do
    @moduledoc """
    `Rez.AST.NodeValidator.Validation` implements the `Validation` struct
    that is passed through the validation pipeline and which collects progress
    and errors as nodes are validated.
    """

    alias __MODULE__

    defstruct game: nil, node: nil, errors: [], validated: []

    def add_error(%Validation{errors: errors} = validation, node, error) do
      %{validation | errors: [{node, error} | errors]}
    end

    def merge(
          %Validation{errors: parent_errors, validated: parent_validated} = parent_validation,
          %Validation{errors: child_errors, validated: child_validated}
        ) do
      %{
        parent_validation
        | errors: parent_errors ++ child_errors,
          validated: parent_validated ++ child_validated
      }
    end
  end

  alias Rez.AST.Attribute
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.AST.Game
  alias Rez.AST.NodeValidator.Validation
  alias Rez.Utils.Search

  def validate_root(%Game{} = game) do
    validate(game, game)
  end

  def validate(node, game) do
    if NodeHelper.get_attr_value(node, "$template", false) == true do
      %Validation{game: game, node: node}
    else
      validate(%Validation{game: game, node: node})
    end
  end

  def validate(%Validation{} = validation) do
    validation
    |> validate_specification()
    |> validate_children()
    |> record_validation()
  end

  def validate_specification(%Validation{game: game, node: node} = pre_validation) do
    node
    |> Node.validators()
    |> Enum.reduce(
      pre_validation,
      fn validator, validation ->
        case validator.(node, game) do
          :ok -> validation
          {:error, reason} -> Validation.add_error(validation, node, reason)
        end
      end
    )
  end

  def validate_children(%Validation{game: game, node: node} = parent_validation) do
    Enum.reduce(
      Node.children(node),
      parent_validation,
      fn child, validation ->
        Validation.merge(validation, validate(child, game))
      end
    )
  end

  def record_validation(%Validation{node: node, validated: validated} = validation) do
    %{validation | validated: [NodeHelper.description(node) | validated]}
  end

  def node_has_children?(child_key, chained_validator \\ nil) do
    fn node, game ->
      case Map.get(node, child_key) do
        nil ->
          {:error, "Does not support children for #{child_key}"}

        children ->
          case {Enum.empty?(children), chained_validator} do
            {true, _} ->
              {:error, "Has no children for #{child_key}"}

            {false, nil} ->
              :ok

            {false, validator} ->
              validator.(node, game)
          end
      end
    end
  end

  def node_passes?(validator) do
    fn node, game ->
      validator.(node, game)
    end
  end

  def find_attribute_in_node(attr_key) do
    fn %{attributes: attributes} = _node ->
      case Map.get(attributes, attr_key) do
        nil ->
          :not_found

        %Attribute{} = attr ->
          {:found, attr}
      end
    end
  end

  def get_parents_of_node(node_map) do
    fn %{attributes: attributes} = _node ->
      default_no_parents = Attribute.list("_parents", [])

      attributes
      |> Map.get("_parents", default_no_parents)
      |> Map.get(:value)
      |> Enum.map(fn {:keyword, parent_id} ->
        Map.get(node_map, to_string(parent_id))
      end)
    end
  end

  def find_attribute(%Game{by_id: node_map}, node, attr_key)
      when not is_nil(node) and is_binary(attr_key) do
    Search.search(
      node,
      find_attribute_in_node(attr_key),
      get_parents_of_node(node_map)
    )
  end

  # The first two attribute validations establish an attribute that is the
  # target of chained validators. Chained validators receive attr, node, game
  # as arguments.

  def attribute_present?(attr_key, chained_validator \\ nil) do
    fn node, game ->
      case {find_attribute(game, node, attr_key), is_nil(chained_validator)} do
        {nil, _} ->
          {:error, "Missing required attribute: #{attr_key}"}

        {_attr, true} ->
          :ok

        {attr, false} ->
          chained_validator.(attr, node, game)
      end
    end
  end

  def attribute_if_present?(attr_key, chained_validator) when not is_nil(chained_validator) do
    fn node, game ->
      case find_attribute(game, node, attr_key) do
        nil ->
          :ok

        %Attribute{} = attr ->
          chained_validator.(attr, node, game)
      end
    end
  end

  def attribute_either?(validator_1, validator_2) do
    fn attr, node, game ->
      case validator_1.(attr, node, game) do
        :ok ->
          :ok

        {:error, error_1} ->
          case validator_2.(attr, node, game) do
            :ok ->
              :ok

            {:error, error_2} ->
              {:error, "Error: #{error_1} / #{error_2}"}
          end
      end
    end
  end

  def attribute_one_of_present?(attr_keys, exclusive)
      when is_list(attr_keys) and is_boolean(exclusive) do
    fn node, game ->
      count_present =
        attr_keys
        |> Enum.map(&find_attribute(game, node, &1))
        |> Enum.filter(&Function.identity/1)
        |> Enum.count()

      case {count_present, exclusive} do
        {0, _} ->
          {:error, "One of #{inspect(attr_keys)} is expected to be defined."}

        {1, _} ->
          :ok

        {_, false} ->
          :ok

        {_, true} ->
          {:error, "Only one of #{inspect(attr_keys)} should be defined."}
      end
    end
  end

  @doc """
    A chained validator that tests for the presence of other attributes that
    become required when the main attribute is present.

    For example if "consumable" is true it requires "uses":

    attribute_if_present?("consumable",
      other_attributes_present?("uses"))
  """
  def other_attributes_present?(required_attrs, chained_validator \\ nil)
      when is_list(required_attrs) do
    fn attr, %{attributes: attributes} = node, game ->
      missing =
        Enum.reject(required_attrs, fn attr_key ->
          Map.has_key?(attributes, attr_key)
        end)

      case {Enum.empty?(missing), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          desc = missing |> Enum.map_join(", ", fn key -> "'" <> key <> "'" end)
          {:error, "Attribute '#{attr.name}' requires #{desc} to be present"}
      end
    end
  end

  def attribute_must_not_be_present?(attr_key) do
    fn %{attributes: attributes} = _node, _game ->
      case Map.get(attributes, attr_key) do
        nil ->
          :ok

        value ->
          {:error, "#{attr_key} is not permitted (was: #{value})"}
      end
    end
  end

  def attribute_is_keyword_set?(chained_validator \\ nil) do
    attribute_has_type?(
      :set,
      attribute_if_not_empty_coll?(attribute_coll_of?(:keyword, chained_validator))
    )
  end

  @syntax %{
    attr_ref: ~s|&elem_id.attr_name|,
    elem_ref: ~s|#elem_id|,
    string: ~s|"string"|,
    list: ~s|[item1 item2 ...]|,
    set: ~s|\#{item1 item2 ...}|
  }

  def syntax_for_type(type) do
    Map.get(@syntax, type)
  end

  def syntax_help(types) when is_list(types) do
    help = types |> Enum.map(&syntax_for_type/1) |> Enum.reject(&is_nil/1)

    case help do
      [] ->
        ""

      list ->
        " (syntax: " <> Enum.join(list, ", ") <> ")"
    end
  end

  def syntax_help(type) do
    case syntax_for_type(type) do
      nil ->
        ""

      syntax ->
        " (syntax: " <> syntax <> ")"
    end
  end

  def attribute_has_type?(query, chained_validator \\ nil)

  def attribute_has_type?(expected_type, chained_validator) when is_atom(expected_type) do
    fn %{name: name, type: type} = attr, node, game ->
      case {type, is_nil(chained_validator)} do
        {^expected_type, true} ->
          :ok

        {^expected_type, false} ->
          chained_validator.(attr, node, game)

        {unexpected_type, _} ->
          {:error,
           "Attribute '#{name}' expected to have type '#{to_string(expected_type)}'#{syntax_help(expected_type)}, was '#{to_string(unexpected_type)}'"}
      end
    end
  end

  def attribute_has_type?(expected_types, chained_validator)
      when is_list(expected_types) do
    fn %{name: name, type: type} = attr, node, game ->
      case({Enum.member?(expected_types, type), is_nil(chained_validator)}) do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          types =
            Enum.map_join(expected_types, ", ", fn type -> "'" <> to_string(type) <> "'" end)

          {:error,
           "Attribute '#{name}' is expected to be one of #{types}#{syntax_help(expected_types)} but was #{to_string(type)}"}
      end
    end
  end

  def attribute_value_is_one_of?(values, chained_validator \\ nil) when is_list(values) do
    fn %{name: name, value: value} = attr, node, game ->
      case {Enum.member?(values, value), is_nil(chained_validator)} do
        {false, _} ->
          {:error,
           "Attribute '#{name}' is required to have a value from [#{inspect(values)}] but was #{value}"}

        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)
      end
    end
  end

  def attribute_if_not_empty_coll?(chained_validator) do
    fn %{value: coll} = attr, node, game ->
      if Enum.empty?(coll) do
        :ok
      else
        chained_validator.(attr, node, game)
      end
    end
  end

  def attribute_not_empty_coll?(chained_validator \\ nil) do
    fn %{name: name, value: lst} = attr, node, game ->
      case {Enum.empty?(lst), is_nil(chained_validator)} do
        {false, true} ->
          :ok

        {false, false} ->
          chained_validator.(attr, node, game)

        {true, _} ->
          {:error, "Attribute '#{name}' must have at least one entry!"}
      end
    end
  end

  def attribute_coll_of?(expected, chained_validator \\ nil)

  def attribute_coll_of?(expected_types, chained_validator) when is_list(expected_types) do
    fn %{name: name, value: coll} = attr, node, game ->
      unexpected_types =
        coll
        |> Enum.map(fn {type, _} -> type end)
        |> Enum.filter(fn type -> !Enum.member?(expected_types, type) end)

      case {unexpected_types, is_nil(chained_validator)} do
        {[], true} ->
          :ok

        {[], false} ->
          chained_validator.(attr, node, game)

        {types, _} ->
          wrong_types = types |> Enum.uniq() |> Enum.join(", ")

          {:error,
           "In collection #{name} found unexpected types (#{wrong_types}) expected one of (#{Enum.join(expected_types, ", ")})"}
      end
    end
  end

  def attribute_coll_of?(expected_type, chained_validator) do
    attribute_coll_of?([expected_type], chained_validator)
  end

  @doc """
  `attribute_list_references/4` validates that the references in the list
  refer to objects of the specified `target_class` within the `parent`.

  It assumes that the attribute has already been validated to be (1) a list,
  (2) a list of elem_refs.

  It returns `{:error, "reason"}` if an object of a different class is found
  in the list. Otherwise it returns `:ok` or, if a `chained_validator` is
  passed, the result of calling the validator on the same node.
  """
  def attribute_list_references?(element, chained_validator \\ nil) when is_binary(element) do
    fn %{name: name, value: refs} = attr, node, %Game{id_map: id_map} = game ->
      invalid_refs =
        Enum.reject(refs, fn {_, ref_id} ->
          match?({^element, _, _}, Map.get(id_map, ref_id))
        end)

      case {Enum.empty?(invalid_refs), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          bad_elem_refs = Enum.map_join(invalid_refs, ", ", fn {_id, ref_id} -> "##{ref_id}" end)

          {:error,
           "Attribute '#{name}' expected to refer to a list from '#{element}' but #{bad_elem_refs} does not"}
      end
    end
  end

  def attribute_refers_to?(element, chained_validator \\ nil) when is_binary(element) do
    fn %{name: name, value: value} = attr, node, %Game{id_map: id_map} = game ->
      case {Map.get(id_map, value), is_nil(chained_validator)} do
        {nil, _} ->
          {:error,
           "Expected #{node.id}/#{name} to refer to a #{element} but the id '#{value}' was not found."}

        {{^element, _, _}, true} ->
          :ok

        {{^element, _, _}, false} ->
          chained_validator.(attr, node, game)

        {{other_element, _, _}, _} ->
          {:error, "Expected #{value} to map to |#{element}| but found |#{other_element}|"}
      end
    end
  end

  @doc """
  `attribute_passes?/2` is a general, catch-all, validator that passes the
  attribute to a given function to return `:ok`|`{:error, reason}` using its own
  logic.
  """
  def attribute_passes?(validator) when is_function(validator) do
    fn attr, node, game ->
      validator.(attr, node, game)
    end
  end

  def validate_if_value?(test_value, chained_validator \\ nil) do
    fn %{value: value} = attr, node, game ->
      if value == test_value do
        chained_validator.(attr, node, game)
      else
        :ok
      end
    end
  end

  def validate_value_contains?(query, error, chained_validator \\ nil) do
    fn %{value: value} = attr, node, game ->
      case {String.contains?(to_string(value), query), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error, error}
      end
    end
  end

  def validate_value_matches?(regex, error, chained_validator \\ nil) do
    fn %{value: value} = attr, node, game ->
      case {String.match?(to_string(value), regex), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error, error}
      end
    end
  end

  def value_passes?(pred, test_desc, chained_validator \\ nil) do
    fn %{name: name, value: value} = attr, node, game ->
      case {pred.(value), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error, "Attribute '#{name}': #{test_desc}"}
      end
    end
  end

  def validate_is_elem?(chained_validator \\ nil) do
    fn %{name: name, value: value} = attr, node, %{id_map: id_map} = game ->
      case {Map.has_key?(id_map, value), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error, "Attribute '#{name}' should refer to a valid id but ##{value} was not found."}
      end
    end
  end

  def validate_has_params?(count, chained_validator \\ nil) do
    fn %{name: name, value: {_fn_style, params, _}} = attr, node, game ->
      case {count == Enum.count(params), is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error,
           "Attribute: '#{name}' should be a function of #{count} arguments, found #{Enum.count(params)}!"}
      end
    end
  end

  def validate_expects_params?(expected_params, chained_validator \\ nil) do
    fn %{name: name, value: {_fn_style, params, _}} = attr, node, game ->
      case {expected_params == params, is_nil(chained_validator)} do
        {true, true} ->
          :ok

        {true, false} ->
          chained_validator.(attr, node, game)

        {false, _} ->
          {:error,
           "Attribute: '#{name}' was expected to be a function with arguments: #{inspect(expected_params)}, found: #{inspect(params)}"}
      end
    end
  end

  def validate_is_btree?(chained_validator \\ nil) do
    fn %{name: name, type: type, value: value} = attr, node, game ->
      case {type, value} do
        # Allow empty task trees although this may break later when we attempt to interpret it
        {:btree, []} ->
          :ok

        {:btree, root_task} ->
          case {validate_task(game, root_task), is_nil(chained_validator)} do
            {:ok, true} ->
              :ok

            {:ok, false} ->
              chained_validator.(attr, node, game)

            {error, _} ->
              error
          end

        invalid_tree ->
          {:error,
           "Attribute: '#{name}' was expected to be a behaviour tree! Got: #{inspect(invalid_tree)}"}
      end
    end
  end

  defp validate_task(%Game{tasks: tasks} = game, {:node, task_id, options, children}) do
    case Map.get(tasks, task_id) do
      nil ->
        {:error, "Undefined behaviour #{task_id}"}

      task ->
        with :ok <- validate_task_child_count(task, Enum.count(children)),
             :ok <- validate_task_options(task, options),
             :ok <- validate_child_tasks(game, children) do
          :ok
        end
    end
  end

  defp validate_task(_game, node) do
    {:error, "expected '#{inspect(node)}' to be a behaviour task"}
  end

  defp validate_task_child_count(task, child_count) do
    min_children = NodeHelper.get_attr_value(task, "min_children", -1)
    max_children = NodeHelper.get_attr_value(task, "max_children", :infinity)

    case {child_count < min_children, child_count > max_children} do
      {false, false} ->
        :ok

      {false, true} ->
        {:error, "Requires at most #{max_children} children"}

      {true, false} ->
        {:error, "Requires at least #{min_children} children"}

      {true, true} ->
        {:error, "Something impossible happened. Both too few and too many children. What gives?"}
    end
  end

  defp validate_task_options(task, options) do
    required_opts = NodeHelper.get_attr_value(task, "options", [])

    Enum.reduce_while(required_opts, :ok, fn {_, opt}, status ->
      case Map.has_key?(options, opt) do
        true ->
          {:cont, status}

        false ->
          {:halt, {:error, "Missing required option #{opt}"}}
      end
    end)
  end

  defp validate_child_tasks(game, children) do
    child_errors =
      children
      |> Enum.map(fn child -> validate_task(game, child) end)
      |> Enum.reject(fn result -> result == :ok end)
      |> Enum.map(fn {:error, reason} -> reason end)

    case child_errors do
      [] ->
        :ok

      errors ->
        {:error, Enum.join(errors, ", ")}
    end
  end
end
