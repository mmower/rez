defmodule Rez.Compiler.Phases.ResolveConstants do
  @moduledoc """
  Resolves constant references in attributes.

  This phase processes all nodes and replaces {:const_ref, name} attribute values
  with the actual constant values from the constants table.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.Attribute

  def run_phase(
        %Compilation{status: :ok, content: content, constants: constants, progress: progress} =
          compilation
      ) do
    resolved_content = Enum.map(content, &resolve_constants_in_node(&1, constants))

    %{
      compilation
      | content: resolved_content,
        progress: ["Resolved constant references" | progress]
    }
  end

  def run_phase(%Compilation{status: :error} = compilation), do: compilation

  defp resolve_constants_in_node(%{attributes: attributes} = node, constants) do
    resolved_attributes =
      attributes
      |> Enum.map(fn {attr_name, attr} ->
        {attr_name, resolve_constants_in_attribute(attr, constants)}
      end)
      |> Enum.into(%{})

    %{node | attributes: resolved_attributes}
  end

  defp resolve_constants_in_node(node, _constants), do: node

  defp resolve_constants_in_attribute(
         %Attribute{type: :const_ref, value: const_name} = attr,
         constants
       ) do
    case Map.get(constants, const_name) do
      nil ->
        # This should have been caught in validation, but handle gracefully
        attr

      {value_type, value} ->
        # Replace the const_ref with the actual value
        %{attr | type: value_type, value: value}
    end
  end

  defp resolve_constants_in_attribute(attr, _constants), do: attr
end
