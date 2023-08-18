defmodule Rez.Compiler.TemplateCompiler do
  @moduledoc """
  The Rez TemplateCompiler translates template texts into JavaScript rendering functions.

  A rendering function takes a map of bindings where keys are game object id's and
  values are the respective game objects.

  The following macros are available:

  ${binding.attribute} -> returns the binding attribute value directly

  using filters (borrowed from Liquid)

  ${binding.attribute | filter}
  ${binding.attribute | filter: argument}
  ${binding.attribute | filter1 | filter2 | ...}
  """
  alias Rez.Compiler.TemplateCompiler.Filters
  alias Rez.Compiler.TemplateCompiler.Values

  def compile({:template, chunks}) do
    "function(bindings, filters) {return #{compile_chunks(chunks)}.reduce((text, f) => text + f(bindings, filters), \"\");}"
  end

  def compile_chunks(chunks) when is_list(chunks) do
    "[" <> Enum.map_join(chunks, ",", &compile_chunk/1) <> "]"
  end

  def compile_chunk(s) when is_binary(s) do
    "(bindings, filters) => \"#{s}\""
  end

  def compile_chunk({:interpolate, {:expression, expr, filters}}) when is_list(filters) do
    "(bindings, filters) => {return " <>
      Filters.js_apply_filters_to_value("bindings", filters, Values.js_exp("bindings", expr)) <>
      ";}"
  end

  defmodule Values do
    def js_exp(bindings_map_name, {:string, s}),
      do: "(function(_) {return \"#{s}\";})(#{bindings_map_name})"

    def js_exp(bindings_map_name, {:number, n}),
      do: "(function(_) {return #{n};})(#{bindings_map_name})"

    def js_exp(bindings_map_name, {:bool, b}),
      do: "(function(_){return #{b};})(#{bindings_map_name})"

    def js_exp(bindings_map_name, {:lookup, binding_name, attribute_name}),
      do:
        "(function(#{bindings_map_name}) {return #{bindings_map_name}.#{binding_name}.getAttributeValue(\"#{attribute_name}\");})(#{bindings_map_name})"
  end

  defmodule Filters do
    alias Rez.Compiler.TemplateCompiler.Values

    def js_params(_bindings_map_name, []), do: ""

    def js_params(bindings_map_name, params) when is_list(params) do
      Enum.map_join(params, ",", fn param -> Values.js_exp(bindings_map_name, param) end)
    end

    def js_apply_filter(bindings_map_name, {filter, []}) do
      "(#{bindings_map_name}, value) => filters.#{filter}(value)"
    end

    def js_apply_filter(bindings_map_name, {filter, params}) do
      "(#{bindings_map_name}, value) => filters.#{filter}(value,#{js_params(bindings_map_name, params)})"
    end

    def js_filter_list(bindings_map_name, filters) do
      "[" <>
        Enum.map_join(filters, ",", fn filter -> js_apply_filter(bindings_map_name, filter) end) <>
        "]"
    end

    @doc """
    Filters are a list such as [{"capitalize", []}, {"trim", [{:number, 40}, {:string, "..."}]}]
    These filters are turned into a JS array that can be used to reduce the initial value that
    is contained in the JS variable named by the 'var_name' parameter.
    """
    def js_apply_filters_to_value(bindings_map_name, filters, initial_value)
        when is_list(filters) do
      "#{js_filter_list(bindings_map_name, filters)}.reduce((v, f) => {return f(#{bindings_map_name}, v)}, #{initial_value})"
    end
  end
end
