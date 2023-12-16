defmodule Rez.Parser.Trace do
  def trace(enabled) when is_boolean(enabled) do
    Ergo.Parser.combinator(:trace, "trace", fn %Ergo.Context{} = ctx ->
      Map.put(ctx, :tracing, enabled)
    end)
  end

  def trace_out(s) when is_binary(s) do
    Ergo.Parser.combinator(:trace_out, "s_trace_out", fn %Ergo.Context{} = ctx ->
      IO.puts(s)
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
