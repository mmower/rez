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

  def js_create_fn(expr, ret),
    do: ~s|function(bindings) {#{if ret, do: "return"} #{expr};}|

  def compile({:source_template, chunks}) do
    compiled_chunks = compile_chunks(chunks)
    reducer = ~s|function(text, f) {return text + f(bindings)}|
    body = ~s|#{compiled_chunks}.reduce(#{reducer}, "")|
    {:compiled_template, js_create_fn(body, true)}
  end

  def compile_chunks(chunks) when is_list(chunks) do
    "[" <> Enum.map_join(chunks, ",", &compile_chunk/1) <> "]"
  end

  @doc """
    Compiles a string chunk into a function that returns the string. We use a
    Javascript template literal here because it allows for multi-line strings.
    Template literals also use the ${…} interpolation syntax but that is not
    a problem as Rez template expressions are in other chunks.
  """
  def compile_chunk(s) when is_binary(s) do
    js_create_fn(~s|`#{s}`|, true)
  end

  def compile_chunk({:interpolate, {:expression, expr, []}}) do
    js_create_fn(Values.js_exp("bindings", expr), true)
  end

  def compile_chunk({:interpolate, {:expression, expr, expr_filters}})
      when is_list(expr_filters) do
    applied_filters =
      Filters.js_apply_expr_filters_to_value(
        "bindings",
        expr_filters,
        Values.js_exp("bindings", expr)
      )

    js_create_fn(applied_filters, true)
  end

  def compile_chunk({:conditional, expr, content}) do
    {:compiled_template, sub_template} = compile(content)

    body = ~s|
    if(evaluateExpression(`#{expr}`, bindings)) {
      const sub_template = #{sub_template};
      return sub_template(bindings);
    } else {
      return "";
    }|

    js_create_fn(body, false)
  end

  def compile_chunk({:conditional, expr, true_content, false_content}) do
    {:compiled_template, true_template} = compile(true_content)
    {:compiled_template, false_template} = compile(false_content)

    body = ~s|
    if(evaluateExpression(`#{expr}`, bindings)) {
      const true_template = #{true_template};
      return true_template(bindings);
    } else {
      const false_template = #{false_template};
      return false_template(bindings);
    }|

    js_create_fn(body, false)
  end

  def compile_chunk({:foreach, iter_name, binding_spec, content}) do
    compile_chunk({:foreach, iter_name, binding_spec, content, {:source_template, [""]}})
  end

  def compile_chunk({:foreach, iter_name, {:bound_path, bound_path}, content, divider}) do
    {:compiled_template, content_template} = compile(content)
    {:compiled_template, divider_template} = compile(divider)

    [bound_obj | _] = bound_path
    bound_path = Enum.join(bound_path, ".")
    binding_spec = "bindings." <> bound_path

    body =
      ~s|
    const binding = bindings.#{bound_obj};
    if(typeof(binding) === "undefined") {
      throw `#{bound_obj} must be defined in bindings!`;
    }

    const iterable = #{binding_spec};
    if(typeof(iterable) === "undefined") {
      throw `#{bound_path} must be bound`;
    }
    if(!Array.isArray(iterable)) {
      throw `#{bound_path} must bind to a list`;
    }
    const content_template = #{content_template};
    const divider_template = #{divider_template};

    const iter_output = iterable.map((#{iter_name}) => {
      const iter_bindings = {...bindings, #{iter_name}: #{iter_name}};
      return content_template(iter_bindings)
    }).join(divider_template(bindings));

    return iter_output;|

    js_create_fn(body, false)
  end

  defmodule Values do
    def js_make_fn(bindings_map_name, expr),
      do: ~s|function(#{bindings_map_name}) {return #{expr};}|

    def js_apply_fn(bindings_map_name, expr) do
      f = js_make_fn(bindings_map_name, expr)
      ~s|(#{f})(#{bindings_map_name})|
    end

    def js_exp(bindings_map_name, {:string, s}),
      do: js_apply_fn(bindings_map_name, ~s|"#{s}"|)

    def js_exp(bindings_map_name, {:number, n}),
      do: js_apply_fn(bindings_map_name, to_string(n))

    def js_exp(bindings_map_name, {:bool, b}),
      do: js_apply_fn(bindings_map_name, to_string(b))

    def js_exp(bindings_map_name, {:list, l}) do
      list = Enum.map_join(l, ",", fn val -> js_exp(bindings_map_name, val) end)
      js_apply_fn(bindings_map_name, "[#{list}]")
    end

    def js_exp(bindings_map_name, {:bound_path, bound_path}),
      do: js_apply_fn(bindings_map_name, "#{bindings_map_name}.#{Enum.join(bound_path, ".")}")
  end

  defmodule Filters do
    alias Rez.Compiler.TemplateCompiler.Values

    def js_function([], body) do
      "function() {#{body}}"
    end

    def js_function(args, body) do
      "function(#{Enum.join(args, ", ")}) {#{body}}"
    end

    def js_params(_bindings_map_name, []), do: ""

    def js_params(bindings_map_name, params) when is_list(params) do
      Enum.map_join(params, ",", fn param -> Values.js_exp(bindings_map_name, param) end)
    end

    def js_expr_filter_fn(expr_filter_name) do
      "Rez.template_expression_filters.#{expr_filter_name}"
    end

    def js_apply_expr_filter(bindings_map_name, {expr_filter_name, params}) do
      expr_filter_params = js_params(bindings_map_name, params)
      expr_filter_call = js_expr_filter_fn(expr_filter_name)

      expr_filter_params =
        case expr_filter_params do
          "" -> "value"
          s -> "value, #{s}"
        end

      #  "value, #{expr_filter_params}"
      expr_filter_call = "#{expr_filter_call}(#{expr_filter_params})"
      js_function([bindings_map_name, "value"], "return #{expr_filter_call};")
    end

    def js_expr_filter_list(bindings_map_name, expr_filters) do
      expr_filter_list =
        Enum.map_join(expr_filters, ",", &js_apply_expr_filter(bindings_map_name, &1))

      "[#{expr_filter_list}]"
    end

    @doc """
    Filters are a list such as [{"capitalize", []}, {"trim", [{:number, 40}, {:string, "..."}]}]
    These filters are turned into a JS array that can be used to reduce the initial value that
    is contained in the JS variable named by the 'var_name' parameter.
    """
    def js_apply_expr_filters_to_value(bindings_map_name, expr_filters, initial_value)
        when is_list(expr_filters) do
      expr_filter_list = js_expr_filter_list(bindings_map_name, expr_filters)

      expr_filter_call =
        "function(value, expr_filter) {return expr_filter(#{bindings_map_name}, value);}"

      "#{expr_filter_list}.reduce(#{expr_filter_call}, #{initial_value})"
    end
  end
end
