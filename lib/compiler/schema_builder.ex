defmodule Rez.Compiler.SchemaBuilder do
  @moduledoc """
  Converts parsed schema expressions such as {:kind, [keywords]} into instances
  of a %SchemaRule{} with an Elixir anon function to implement the behaviour.
  """
  alias Rez.AST.TypeHierarchy
  alias Rez.Utils

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Validation

  defmodule SchemaRule do
    @moduledoc """
    Represents a schema rule which corresponds to a validation run against
    an attribute.

    Schema rules have a priority to allow them to be specified in any order
    but run in a predictable order.

    They have a human-readable description

    'f/3' is the function that implements the schema rule.

    It gets passed the node being validated, a %Validation{} struct that holds
    validation results, and an id based map of nodes so that other nodes can
    potentially be referred to during validation.

    For example if validating that a node refers to another existing node, the
    id_map can be used to look it up.
    """
    defstruct [:priority, :description, :f]

    def new(priority, description, f)
        when is_number(priority) and priority > 0 and is_binary(description) and is_function(f, 3) do
      %SchemaRule{priority: priority, description: description, f: f}
    end

    def execute(%SchemaRule{f: f}, %{} = node, %Validation{} = validation, %{} = lookup) do
      f.(node, validation, lookup)
    end
  end

  defmodule PatternRule do
    @moduledoc """
    Represents a pattern-based schema rule that matches attributes dynamically
    using regex patterns.

    Pattern rules are applied to all attributes in a node that match the compiled
    regex pattern. They have the same priority system as SchemaRules.

    The 'pattern' field contains the compiled regex.
    The 'f/4' function takes (attr_name, node, validation, lookup) where attr_name
    is the matched attribute name.
    """
    defstruct [:priority, :description, :pattern, :f]

    def new(priority, description, pattern_string, f)
        when is_number(priority) and priority > 0 and is_binary(description) and
               is_binary(pattern_string) and is_function(f, 4) do
      {:ok, compiled_pattern} = Regex.compile(pattern_string)

      %PatternRule{
        priority: priority,
        description: description,
        pattern: compiled_pattern,
        f: f
      }
    end

    def execute(
          %PatternRule{f: f},
          attr_name,
          %{} = node,
          %Validation{} = validation,
          %{} = lookup
        ) do
      f.(attr_name, node, validation, lookup)
    end

    def matches?(%PatternRule{pattern: pattern}, attr_name) when is_binary(attr_name) do
      Regex.match?(pattern, attr_name)
    end
  end

  def build(attr_name, schema_expressions)
      when is_binary(attr_name) and is_list(schema_expressions) do
    try do
      rules =
        schema_expressions
        |> Enum.map(fn expression ->
          rule_fn(attr_name, expression)
        end)

      {:ok, rules}
    rescue
      e in FunctionClauseError ->
        {:error, "Unsupported schema expression for attribute '#{attr_name}': #{inspect(e.args)}"}
    end
  end

  def build_pattern(pattern_string, schema_expressions)
      when is_binary(pattern_string) and is_list(schema_expressions) do
    try do
      rules =
        schema_expressions
        |> Enum.map(&pattern_rule_fn(pattern_string, &1))

      {:ok, rules}
    rescue
      e in FunctionClauseError ->
        {:error,
         "Unsupported pattern rule expression for pattern '/#{pattern_string}/': #{inspect(e.args)}"}
    end
  end

  defp rule_fn(attr_name, {:allowed, allowed}) do
    SchemaRule.new(
      1,
      "Attribute #{attr_name} is #{if !allowed, do: "not "}allowed",
      fn node, validation, _lookup ->
        if !allowed && NodeHelper.has_attr?(node, attr_name) do
          {node, Validation.add_error(validation, node, "#{attr_name} is not allowed")}
        else
          {node, validation}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:kind, kinds}) when is_list(kinds) do
    SchemaRule.new(
      3,
      if(length(kinds) == 1,
        do: "Validate #{attr_name} is of kind #{List.first(kinds)}",
        else: "Validate #{attr_name} is one of #{Utils.english_list(kinds)}"
      ),
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :placeholder} ->
            # Placeholders bypass kind validation
            {node, validation}

          %{type: t} ->
            if t in kinds do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 if(length(kinds) == 1,
                   do: "#{attr_name} must be of kind #{List.first(kinds)} but was #{t}",
                   else: "#{attr_name} must be one of #{Utils.english_list(kinds)} but was #{t}}"
                 )
               )}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:coll_kind, kinds}) when is_list(kinds) do
    SchemaRule.new(
      4,
      "Validate #{attr_name} is a collection holding #{Utils.english_list(kinds)}",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: type, value: values} when type in [:list, :set] ->
            if Enum.all?(values, fn {kind, _} -> kind in kinds end) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be a collection of #{inspect(kinds)}"
               )}
            end

          %{type: type} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} must be a collection type (list or set) but was #{inspect(type)}"
             )}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:min_length, min_length}) do
    SchemaRule.new(
      3,
      "Validate #{attr_name} is a collection of at least #{min_length} items or a string of at least #{min_length} characters.",
      fn node, validation, _lookup ->
        if min_length < 1 do
          {node, validation}
        else
          case NodeHelper.get_attr(node, attr_name) do
            nil ->
              {node, validation}

            %Rez.AST.Attribute{type: :string, value: s} ->
              if String.length(s) < min_length do
                {
                  node,
                  Validation.add_error(
                    validation,
                    node,
                    "#{attr_name} is expected to be a string of at least #{min_length} characters, was #{String.length(s)}"
                  )
                }
              else
                {node, validation}
              end

            %Rez.AST.Attribute{type: type, value: contents} when type in [:list, :set] ->
              if Enum.count(contents) < min_length do
                {node,
                 Validation.add_error(
                   validation,
                   node,
                   "#{attr_name} is expected to be a collection of at least #{min_length} elements but was #{Enum.count(contents)}"
                 )}
              else
                {node, validation}
              end

            {type, _} ->
              {
                node,
                Validation.add_error(
                  validation,
                  node,
                  "#{attr_name} was expected to be a list, set, or string but was #{inspect(type)}"
                )
              }
          end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:max_length, max_length}) do
    SchemaRule.new(
      3,
      "Validate #{attr_name} is a collection of at most #{max_length} items or a string of at most #{max_length} characters.",
      fn node, validation, _lookup ->
        if max_length < 1 do
          {node, validation}
        else
          case NodeHelper.get_attr(node, attr_name) do
            nil ->
              {node, validation}

            %Rez.AST.Attribute{type: :string, value: s} ->
              if String.length(s) > max_length do
                {
                  node,
                  Validation.add_error(
                    validation,
                    node,
                    "#{attr_name} is expected to be a string of at most #{max_length} characters, was #{String.length(s)}"
                  )
                }
              else
                {node, validation}
              end

            %Rez.AST.Attribute{type: type, value: contents} when type in [:list, :set] ->
              if Enum.count(contents) > max_length do
                {node,
                 Validation.add_error(
                   validation,
                   node,
                   "#{attr_name} is expected to be a collection of at most #{max_length} elements but was #{Enum.count(contents)}"
                 )}
              else
                {node, validation}
              end

            {type, _} ->
              {
                node,
                Validation.add_error(
                  validation,
                  node,
                  "#{attr_name} was expected to be a list, set, or string but was #{inspect(type)}"
                )
              }
          end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:ref_elem, elems}) when is_list(elems) do
    SchemaRule.new(
      4,
      "Validate #{attr_name} is a ref to an element of type #{inspect(elems)}",
      fn node, validation, lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :placeholder} ->
            {node, validation}

          %{type: type, value: elem_id} when type in [:elem_ref, :copy_initializer] ->
            if elem_type_one_of(lookup, elem_id, elems) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} refers to an element id (##{elem_id}) that cannot be found"
               )}
            end

          %{type: t, value: values} when t in [:list, :set] ->
            ref_ids =
              Enum.flat_map(values, fn item ->
                case extract_elem_ref(item) do
                  {:ok, ref} -> [ref]
                  :skip -> []
                end
              end)

            invalid_refs = Enum.reject(ref_ids, &elem_type_one_of(lookup, &1, elems))

            if Enum.empty?(invalid_refs) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} references invalid element ids: #{Enum.map_join(invalid_refs, ", ", &"##{&1}")}"
               )}
            end

          %{type: t} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} is expected to be a ref but was #{inspect(t)}"
             )}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:min_arity, min}) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} has at least #{min} params",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :function, value: {_type, params, _body}} ->
            if length(params) >= min do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} is expected to be a function with at least #{min} params but found #{length(params)}"
               )}
            end

          %{type: t} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} is expected to be a function but was #{inspect(t)}"
             )}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:max_arity, max}) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} has at most #{max} params",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :function, value: {_type, params, _body}} ->
            if length(params) <= max do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} is expected to be a function with at most #{max} params but found #{length(params)}"
               )}
            end

          %{type: t} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} is expected to be a function but was #{inspect(t)}"
             )}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:param_count, expected_count}) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} has #{expected_count} params",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :function, value: {_type, params, _body}} ->
            if Enum.count(params) == expected_count do
              {node, validation}
            else
              Validation.add_error(
                validation,
                node,
                "#{attr_name} was expected to be a function of #{expected_count} params but found #{Enum.count(params)}"
              )
            end

          %{type: t} ->
            Validation.add_error(
              validation,
              node,
              "#{attr_name} is expected to be a function but was #{inspect(t)}"
            )
        end
      end
    )
  end

  defp rule_fn(attr_name, {:xor, attr_names}) when is_list(attr_names) do
    SchemaRule.new(
      6,
      "Validate xor(#{attr_name}, #{inspect(attr_names)})",
      fn node, validation, _lookup ->
        if NodeHelper.has_attr?(node, attr_name) do
          if Enum.any?(attr_names, fn name -> NodeHelper.has_attr?(node, name) end) do
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} cannot appear alongside any of #{inspect(attr_names)}"
             )}
          else
            {node, validation}
          end
        else
          {node, validation}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:and, attr_names}) when is_list(attr_names) do
    SchemaRule.new(
      6,
      "Validate and(#{attr_name}, #{inspect(attr_names)})",
      fn node, validation, _lookup ->
        if NodeHelper.has_attr?(node, attr_name) do
          if Enum.all?(attr_names, fn name -> NodeHelper.has_attr?(node, name) end) do
            {node, validation}
          else
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} requires #{inspect(attr_names)} to also be present"
             )}
          end
        else
          {node, validation}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:or, attr_names}) when is_list(attr_names) do
    SchemaRule.new(
      6,
      "Validate or(#{attr_name}, #{inspect(attr_names)})",
      fn node, validation, _lookup ->
        if NodeHelper.has_attr?(node, attr_name) do
          {node, validation}
        else
          if Enum.any?(attr_names, fn name -> NodeHelper.has_attr?(node, name) end) do
            {node, validation}
          else
            {node,
             Validation.add_error(
               validation,
               node,
               "You must define #{attr_name} or at least one of #{inspect(attr_names)}"
             )}
          end
        end
      end
    )
  end

  defp rule_fn(attr_name, :file_exists) do
    SchemaRule.new(
      7,
      "Validate that file path specified in #{attr_name} exists",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: path} ->
            if File.exists?(path) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} specifies a file path '#{path}' which does not exist"
               )}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:required, required}) do
    SchemaRule.new(
      2,
      "Validate that #{attr_name} is present",
      fn node, validation, _lookup ->
        if !required || NodeHelper.has_attr?(node, attr_name) do
          {node, validation}
        else
          {node, Validation.add_error(validation, node, "#{attr_name} must be defined")}
        end
      end
    )
  end

  defp rule_fn(attr_name, {:contains, sub_str}) do
    SchemaRule.new(
      5,
      "Validate that #{attr_name} contains the string #{sub_str}",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if String.contains?(value, to_string(sub_str)) do
              {node, validation}
            else
              {node,
               Validation.add_error(validation, node, "#{attr_name} must contain #{sub_str}")}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:min_value, min_value}) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} is #{min_value} or higher",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if value >= min_value do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be >= #{min_value} was #{value}"
               )}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:max_value, max_value}) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} is #{max_value} or lower",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if value <= max_value do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be <= #{max_value} was #{value}"
               )}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:in, values}) when is_list(values) do
    SchemaRule.new(
      5,
      "Validate #{attr_name} is one of #{inspect(values)}",
      fn node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if value in values do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 ~s|#{attr_name} must be one of #{inspect(values)} was "#{value}"|
               )}
            end
        end
      end
    )
  end

  # Creates a schema rule to validate that the value of an elements attribute
  # matches another elements attribute taking into account the hierarchy of
  # types established. For example, given the following:
  #
  # @derive :weapon :item
  #
  # @item sword {
  #   type: :weapon
  # }
  #
  # @slot backpack {
  #   accepts: :item
  # }
  #
  # @schema item {
  #   type: {kind: :keyword, required: true, is_a: @slot/accepts}
  #
  # Creates a schema rule that treats the attribute value as a derived keyword
  # and attempts to match it (or an ancestor) to at least one value of the
  # attribute values of the specified element.
  #
  # For example {:is_a, "slot", "accepts}
  #
  # Would create a SchemaRule designed to look at each accepts attribute of
  # every @slot element and fail if none of them matched the attribute value.
  #
  defp rule_fn(attr_name, {:is_a, elem, attr}) do
    SchemaRule.new(
      8,
      "Validate #{attr_name} is_a @#{elem}/#{attr}",
      fn node, validation, %{type_hierarchy: type_hierarchy, type_map: type_map} = _lookup ->
        if Map.has_key?(type_map, "slot") do
          case NodeHelper.get_attr(node, attr_name) do
            nil ->
              {node, validation}

            %{value: base_type} ->
              accepted_types =
                Enum.reduce(Map.get(type_map, "slot"), MapSet.new(), fn slot, types ->
                  MapSet.put(types, NodeHelper.get_attr_value(slot, "accepts"))
                end)

              expanded_types =
                type_hierarchy
                |> TypeHierarchy.expand(base_type)
                |> MapSet.new()

              if MapSet.disjoint?(expanded_types, accepted_types) do
                {node,
                 Validation.add_error(
                   validation,
                   node,
                   ~s|#{attr_name} '#{base_type}' must reference the 'accepts' attribute of at least one @slot (found: #{Enum.join(accepted_types, ", ")})|
                 )}
              else
                {node, validation}
              end
          end
        else
          {node,
           Validation.add_error(validation, node, ~s|There are no slots to hold inventory items|)}
        end
      end
    )
  end

  defp rule_fn(attr_name, :type_exists) do
    SchemaRule.new(
      9,
      "Validate #{attr_name} references a type that exists in the type hierarchy",
      fn node, validation, %{type_hierarchy: type_hierarchy} = _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: type_value} ->
            if TypeHierarchy.has_type?(type_hierarchy, type_value) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} references type ':#{type_value}' which has not been derived with @derive"
               )}
            end
        end
      end
    )
  end

  defp rule_fn(attr_name, {:no_key_overlap, other_attr}) do
    SchemaRule.new(
      6,
      "Validate #{attr_name} has no overlapping keys with #{other_attr}",
      fn node, validation, _lookup ->
        case {NodeHelper.get_attr(node, attr_name), NodeHelper.get_attr(node, other_attr)} do
          {nil, _} ->
            {node, validation}

          {_, nil} ->
            {node, validation}

          {%{type: :list, value: list1}, %{type: :list, value: list2}} ->
            keys1 = extract_binding_keys(list1)
            keys2 = extract_binding_keys(list2)
            overlap = MapSet.intersection(keys1, keys2)

            if MapSet.size(overlap) > 0 do
              conflict_list = overlap |> MapSet.to_list() |> Enum.join(", ")

              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} and #{other_attr} have conflicting names: #{conflict_list}"
               )}
            else
              {node, validation}
            end

          _ ->
            {node, validation}
        end
      end
    )
  end

  defp extract_binding_keys(binding_list) do
    binding_list
    |> Enum.filter(fn {kind, _} -> kind == :list_binding end)
    |> Enum.map(fn {:list_binding, {key, _}} -> key end)
    |> MapSet.new()
  end

  defp extract_elem_ref({:elem_ref, ref}), do: {:ok, ref}

  defp extract_elem_ref({:list_binding, {_prefix, {:source, _deref, {:elem_ref, ref}}}}),
    do: {:ok, ref}

  defp extract_elem_ref(_), do: :skip

  def elem_type_one_of(lookup, elem_id, elems) do
    %{id_map: id_map} = lookup

    case Map.get(id_map, elem_id) do
      nil ->
        false

      %{} = node ->
        alias_chain = NodeHelper.get_meta(node, "alias_chain", [Node.node_type(node)])
        Enum.any?(alias_chain, &(&1 in elems))
    end
  end

  # Pattern rule functions - create PatternRule instances for dynamic attribute matching

  defp pattern_rule_fn(pattern_string, {:kind, kinds}) when is_list(kinds) do
    PatternRule.new(
      3,
      if(length(kinds) == 1,
        do: "Validate attributes matching /#{pattern_string}/ are of kind #{List.first(kinds)}",
        else:
          "Validate attributes matching /#{pattern_string}/ are one of #{Utils.english_list(kinds)}"
      ),
      pattern_string,
      fn attr_name, node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :placeholder} ->
            {node, validation}

          %{type: t} ->
            if t in kinds do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 if(length(kinds) == 1,
                   do: "#{attr_name} must be of kind #{List.first(kinds)} but was #{t}",
                   else: "#{attr_name} must be one of #{Utils.english_list(kinds)} but was #{t}"
                 )
               )}
            end
        end
      end
    )
  end

  defp pattern_rule_fn(pattern_string, {:required, required}) do
    PatternRule.new(
      2,
      "Validate that attributes matching /#{pattern_string}/ are present",
      pattern_string,
      fn attr_name, node, validation, _lookup ->
        if !required || NodeHelper.has_attr?(node, attr_name) do
          {node, validation}
        else
          {node, Validation.add_error(validation, node, "#{attr_name} must be defined")}
        end
      end
    )
  end

  defp pattern_rule_fn(pattern_string, {:ref_elem, elems}) when is_list(elems) do
    PatternRule.new(
      4,
      "Validate attributes matching /#{pattern_string}/ are refs to elements of type #{inspect(elems)}",
      pattern_string,
      fn attr_name, node, validation, lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: :placeholder} ->
            {node, validation}

          %{type: :elem_ref, value: elem_id} ->
            if elem_type_one_of(lookup, elem_id, elems) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} is a ref to a non-existent element (##{elem_id})"
               )}
            end

          %{type: :copy_initializer, value: {elem_id, _prio}} ->
            if elem_type_one_of(lookup, elem_id, elems) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} is a ref to a non-existent element (##{elem_id})"
               )}
            end

          %{type: t} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} is expected to be a ref but was #{inspect(t)}"
             )}
        end
      end
    )
  end

  defp pattern_rule_fn(pattern_string, {:min_value, min_value}) do
    PatternRule.new(
      5,
      "Validate attributes matching /#{pattern_string}/ are #{min_value} or higher",
      pattern_string,
      fn attr_name, node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if value >= min_value do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be >= #{min_value} was #{value}"
               )}
            end
        end
      end
    )
  end

  defp pattern_rule_fn(pattern_string, {:max_value, max_value}) do
    PatternRule.new(
      5,
      "Validate attributes matching /#{pattern_string}/ are #{max_value} or lower",
      pattern_string,
      fn attr_name, node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{value: value} ->
            if value <= max_value do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be <= #{max_value} was #{value}"
               )}
            end
        end
      end
    )
  end

  defp pattern_rule_fn(pattern_string, {:coll_kind, kinds}) when is_list(kinds) do
    PatternRule.new(
      4,
      "Validate attributes matching /#{pattern_string}/ are collections holding #{Utils.english_list(kinds)}",
      pattern_string,
      fn attr_name, node, validation, _lookup ->
        case NodeHelper.get_attr(node, attr_name) do
          nil ->
            {node, validation}

          %{type: type, value: values} when type in [:list, :set] ->
            if Enum.all?(values, fn {kind, _} -> kind in kinds end) do
              {node, validation}
            else
              {node,
               Validation.add_error(
                 validation,
                 node,
                 "#{attr_name} must be a collection of #{inspect(kinds)}"
               )}
            end

          %{type: type} ->
            {node,
             Validation.add_error(
               validation,
               node,
               "#{attr_name} must be a collection type (list or set) but was #{inspect(type)}"
             )}
        end
      end
    )
  end
end
