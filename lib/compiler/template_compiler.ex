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
  alias Rez.AST.ValueEncoder
  alias Rez.Compiler.TemplateCompiler.Filters
  alias Rez.Compiler.TemplateCompiler.Values

  def js_create_fn(expr, ret),
    do: ~s|function(bindings) {#{if ret, do: "return"} #{expr};}|

  @doc """
  Converts a bound path (which may contain index/key tokens) to JavaScript property access.

  Examples:
    ["arr", {:index, 0}] → "bindings.arr[0]"
    ["arr", {:key, "special"}] → "bindings.arr[\"special\"]"
    ["arr", {:bound_index, ["idx"]}] → "bindings.arr[bindings.idx]"
  """
  def bound_path_to_js(path, prefix \\ "bindings") do
    path
    |> Enum.reduce(prefix, fn
      {:index, n}, acc ->
        "#{acc}[#{n}]"

      {:key, k}, acc ->
        ~s|#{acc}["#{k}"]|

      {:bound_index, idx_path}, acc ->
        idx_js = bound_path_to_js(idx_path, "bindings")
        "#{acc}[#{idx_js}]"

      ident, acc when is_binary(ident) ->
        "#{acc}.#{ident}"
    end)
  end

  @doc """
  Extracts the root binding name from a path (the first string identifier).
  """
  def extract_root_binding([first | _]) when is_binary(first), do: first
  def extract_root_binding([{:index, _} | rest]), do: extract_root_binding(rest)
  def extract_root_binding([{:key, _} | rest]), do: extract_root_binding(rest)
  def extract_root_binding([{:bound_index, _} | rest]), do: extract_root_binding(rest)

  def compile({:error, _reason} = error) do
    error
  end

  def compile({:source_template, chunks}) do
    case compile_chunks(chunks) do
      {:error, _reason} = error ->
        error

      compiled_chunks ->
        reducer = ~s|function(text, f) {return text + f(bindings)}|
        body = ~s|#{compiled_chunks}.reduce(#{reducer}, "")|
        {:compiled_template, js_create_fn(body, true)}
    end
  end

  def compile_chunks(chunks) when is_list(chunks) do
    compiled = Enum.map(chunks, &compile_chunk/1)

    case Enum.find(compiled, &match?({:error, _}, &1)) do
      {:error, _reason} = error -> error
      nil -> "[" <> Enum.join(compiled, ",") <> "]"
    end
  end

  def compile_chunk({:error, _reason} = error) do
    error
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

  def compile_chunk({:conditional, cond_exprs}) when is_list(cond_exprs) do
    with :ok <- check_for_errors(cond_exprs),
         {:ok, compiled_exprs} <- compile_conditional_exprs(cond_exprs) do
      compiled_exprs
      |> Enum.reduce({:if, ""}, fn {expr, sub_template}, {test, out} ->
        {:else_if, out <> conditional_expr(test, expr, sub_template)}
      end)
      |> then(fn {_, expr} ->
        expr <> ~s|
      else {
        return "";
      }
      |
      end)
      |> then(fn body ->
        js_create_fn(body, false)
      end)
    end
  end

  def compile_chunk({:do, expr}) do
    body = ~s|
    evaluateExpression(`#{expr}`, bindings, false);
    return "";
    |

    js_create_fn(body, false)
  end

  def compile_chunk({:user_component, name, attributes, nil}) do
    assigns = component_assigns(attributes)

    body = ~s|
    const user_component = window.Rez.user_components['#{name}'];

    if(typeof user_component === "undefined") {
      throw `No user @macro #{name} defined!`;
    } else {
      return user_component(bindings, {#{assigns}}, null);
    }
    |

    js_create_fn(body, false)
  end

  def compile_chunk({:user_component, name, attributes, content}) do
    case compile(content) do
      {:error, _reason} = error ->
        error

      {:compiled_template, compiled_template} ->
        assigns = component_assigns(attributes)

        body = ~s|
        const user_component = window.Rez.user_components['#{name}'];

        const sub_template = #{compiled_template};
        const sub_content = sub_template(bindings);

        if(typeof user_component === "undefined") {
          throw `No user @macro #{name} defined!`;
        } else {
          return user_component(bindings, {#{assigns}}, sub_content);
        }
        |

        js_create_fn(body, false)
    end
  end

  def compile_chunk({:foreach, iter_name, binding_spec, content}) do
    compile_chunk({:foreach, iter_name, binding_spec, content, {:source_template, [""]}})
  end

  def compile_chunk({:foreach, iter_name, {:bound_path, bound_path}, content, divider}) do
    with {:ok, content_template} <- compile_preserving_errors(content),
         {:ok, divider_template} <- compile_preserving_errors(divider) do
      bound_obj = extract_root_binding(bound_path)
      bound_path_str = bound_path_to_js(bound_path, "")
      binding_spec = "bindings" <> bound_path_str

      body =
        ~s|
      const binding = bindings.#{bound_obj};
      if(typeof(binding) === "undefined") {
        throw `#{bound_obj} must be defined in bindings!`;
      }

      const iterable = #{binding_spec};
      if(typeof(iterable) === "undefined") {
        throw `#{bound_path_str} must be bound`;
      }
      if(!Array.isArray(iterable)) {
        throw `#{bound_path_str} must bind to a list`;
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
  end

  def compile_chunk({:partial, t_expr, {:params, params}}) do
    params =
      Enum.map_join(params, ",", fn {key, value} ->
        case value do
          {:string, s} ->
            ~s|#{key}: "#{s}"|

          {:number, n} ->
            ~s|#{key}: #{n}|

          {:boolean, b} ->
            ~s|#{key}: #{b}|

          {:bound_path, path} ->
            ~s|#{key}: #{bound_path_to_js(path)}|
        end
      end)

    partial_id =
      case t_expr do
        {:bound_path, path} -> bound_path_to_js(path)
        {:string, id} -> ~s|"#{id}"|
        {:elem_ref, id} -> ~s|"#{id}"|
        id when is_binary(id) -> "bindings.#{id}"
      end

    body = ~s|
      const partial_id = #{partial_id};
      const partial = $(partial_id);
      partial.$parent = bindings.source;
      const block = new RezBlock("block", partial);
      block.parent_block = bindings.block;
      block.params = {#{params}};
      return block.renderBlock();
    |

    js_create_fn(body, false)
  end

  defp check_for_errors(items) do
    case Enum.find(items, &match?({:error, _}, &1)) do
      {:error, _reason} = error -> error
      nil -> :ok
    end
  end

  defp compile_conditional_exprs(cond_exprs) do
    compiled =
      Enum.map(cond_exprs, fn {expr, template} ->
        case compile(template) do
          {:error, _reason} = error -> error
          {:compiled_template, compiled_template} -> {expr, compiled_template}
        end
      end)

    case Enum.find(compiled, &match?({:error, _}, &1)) do
      {:error, _reason} = error -> error
      nil -> {:ok, compiled}
    end
  end

  defp compile_preserving_errors(template) do
    case compile(template) do
      {:error, _reason} = error -> error
      {:compiled_template, compiled} -> {:ok, compiled}
    end
  end

  def conditional_expr(:if, expr, sub_template) do
    ~s|
    if(evaluateExpression(`#{expr}`, bindings)) {
      const sub_template = #{sub_template};
      return sub_template(bindings);
    }|
  end

  def conditional_expr(:else_if, expr, sub_template) do
    ~s|
    else if(evaluateExpression(`#{expr}`, bindings)) {
      const sub_template = #{sub_template};
      return sub_template(bindings);
    }|
  end

  defp component_assigns(attributes) do
    Enum.map_join(attributes, ",", fn
      {key, {:attr_expr, expr}} ->
        ~s|#{key}: evaluateExpression("#{String.replace(expr, "\"", "\\\"")}", bindings)|

      {key, value} ->
        ~s|#{key}: #{ValueEncoder.encode_value(value)}|
    end)
  end

  defmodule Values do
    @moduledoc """
    Javascript code generation for bound values
    """
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

    def js_exp(bindings_map_name, {:bound_path, bound_path}) do
      js_path = Rez.Compiler.TemplateCompiler.bound_path_to_js(bound_path, bindings_map_name)
      js_apply_fn(bindings_map_name, js_path)
    end

    def js_exp(_bindings_map_name, {:const_ref, const_name}),
      do: "$#{const_name}"
  end

  defmodule Filters do
    @moduledoc """
    Javascript code generation for handling filters for template expressions
    """
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
