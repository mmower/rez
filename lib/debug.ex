defmodule Rez.Debug do
  @moduledoc """
  Tools for getting & setting a debug level, debug logging, and executing
  code at an appropriate debug level. Uses an Agent to store the debug
  level.
  """
  use Agent

  @spec start_link(0..4) :: any()
  def start_link(debug_level) do
    Agent.start_link(fn -> debug_level end, name: __MODULE__)
  end

  @spec dbg_level :: integer()
  def dbg_level() do
    Agent.get(__MODULE__, & &1)
  end

  @spec dbg_do?(level) :: boolean()
  def dbg_do?(level) do
    map_debug_level(level) <= dbg_level()
  end

  @type level :: :error | :warn | :warning | :info | :verbose | :debug
  @spec dbg_log(level, String.t()) :: any()
  def dbg_log(level, message) do
    if dbg_do?(level), do: IO.puts(message)
  end

  def e_log(message), do: dbg_log(:error, message)
  def w_log(message), do: dbg_log(:warn, message)
  def i_log(message), do: dbg_log(:info, message)
  def v_log(message), do: dbg_log(:verbose, message)
  def d_log(message), do: dbg_log(:debug, message)

  @spec map_debug_level(level) :: integer()
  defp map_debug_level(level_key) do
    case level_key do
      :error -> 0
      :warn -> 1
      :warning -> 1
      :info -> 2
      :verbose -> 3
      :debug -> 4
    end
  end
end
