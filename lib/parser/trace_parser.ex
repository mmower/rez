defmodule Rez.Parser.Trace do
  alias Ergo.Parser
  alias Ergo.Context

  def trace(enabled) when is_boolean(enabled) do
    Parser.combinator(:trace, "trace", fn %Context{} = ctx ->
      Map.put(ctx, :tracing, enabled)
    end)
  end

  def tracing?(%Context{} = ctx) do
    Map.get(ctx, :tracing, false)
  end

  def trace_log(ctx, message) do
    IO.puts("[L#{ctx.line}:#{ctx.col}] #{message}")
  end

  def trace_counters() do
    Parser.combinator(:trace_counters, "s_trace_counters", fn %Context{} = ctx ->
      counters = Map.get(ctx, :counters, %{})
      if tracing?(ctx), do: trace_log(ctx, inspect(counters))
      ctx
    end)
  end

  def trace_capture(key) do
    Parser.combinator(:trace_capture, "s_trace_capture", fn %Context{captures: captures} = ctx ->
      if tracing?(ctx) do
        trace_log(ctx, "#{key} = #{Map.get(captures, key, "<not found>")}")
      end

      ctx
    end)
  end

  def trace_input() do
    Parser.combinator(:trace_input, "s_trace_input", fn %Context{input: input} = ctx ->
      if tracing?(ctx) do
        trace_log(ctx, Rez.Utils.ellipsize(input, 400))
      end

      ctx
    end)
  end

  def trace_input(match) when is_binary(match) do
    Parser.combinator(:trace_input, "s_trace_input", fn %Context{input: input} = ctx ->
      if tracing?(ctx) && String.starts_with?(input, match) do
        trace_log(ctx, Rez.Utils.ellipsize(input, 400))
      end

      ctx
    end)
  end

  def trace_out(s) when is_binary(s) do
    Parser.combinator(:trace_out, "s_trace_out", fn %Context{} = ctx ->
      if tracing?(ctx) do
        trace_log(ctx, s)
      end

      ctx
    end)
  end

  def trace_out(f) when is_function(f) do
    Parser.combinator(:trace_out, "f_trace_out", fn %Context{} = ctx ->
      if tracing?(ctx) do
        f.(ctx)
      end

      ctx
    end)
  end

  def trace_ast(parser, message \\ "AST") do
    Parser.combinator(:trace_value, "trace_value", fn %Context{} = ctx ->
      case Parser.invoke(ctx, parser) do
        %{status: :ok} = ok_ctx ->
          if tracing?(ctx) do
            trace_log(ctx, "#{message}: #{inspect(ok_ctx.ast)}")
          end

          ok_ctx

        err_ctx ->
          err_ctx
      end
    end)
  end
end
