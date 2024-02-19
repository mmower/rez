defmodule Rez.Parser.Trace do
  def trace(enabled) when is_boolean(enabled) do
    Ergo.Parser.combinator(:trace, "trace", fn %Ergo.Context{} = ctx ->
      Map.put(ctx, :tracing, enabled)
    end)
  end

  def trace_input() do
    Ergo.Parser.combinator(:trace_input, "s_trace_input", fn %Ergo.Context{input: input} = ctx ->
      IO.puts("L#{ctx.line}:#{ctx.col}>" <> Rez.Utils.ellipsize(input))
      ctx
    end)
  end

  def trace_out(s) when is_binary(s) do
    Ergo.Parser.combinator(:trace_out, "s_trace_out", fn %Ergo.Context{} = ctx ->
      IO.puts("L#{ctx.line}:#{ctx.col}>#{s}")
      ctx
    end)
  end

  def trace_out(f) when is_function(f) do
    Ergo.Parser.combinator(:trace_out, "f_trace_out", fn %Ergo.Context{} = ctx ->
      if Map.get(ctx, :tracing, false) do
        f.(ctx)
      end

      ctx
    end)
  end
end
