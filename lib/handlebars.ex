defmodule Rez.Handlebars do
  use GenServer
  alias Rez.Debug

  @moduledoc """
  `Rez.Handlebars` implements the interface between the Rez compiler and
  the unix `handlebars` command. It depends upon Handlebars having been
  install externally.
  """

  @name :handlebars_compiler_service

  defmodule State do
    @moduledoc false
    defstruct cache_path: nil
  end

  def start_link(cache_path) do
    GenServer.start(__MODULE__, %State{cache_path: cache_path}, name: @name)
  end

  def compile(html, label) do
    GenServer.call(@name, {:compile_html, html, label})
  end

  @impl true
  def init(%State{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:compile_html, html, label}, _from, %{cache_path: cache_path} = state) do
    hash = hash_html(html)
    cache_path = cache_file_path(cache_path, hash)

    case File.read(cache_path) do
      {:ok, template} ->
        {:reply, {:ok, template}, state}

      {:error, :enoent} ->
        case compile_template(html, cache_path, label) do
          {:ok, template} ->
            {:reply, {:ok, template}, state}

          {:error, error} ->
            {:reply, {:error, error}, state}
        end

      {:error, error} ->
        {:reply, {:error, "Unrecoverable error reading cache path: #{cache_path} #{error}"},
         state}
    end
  end

  defp hash_html(html) do
    :crypto.hash(:md5, html) |> Base.encode16()
  end

  defp cache_file_path(cache_path, hash) do
    Path.join(cache_path, "#{hash}.tmpl")
  end

  def run_handlebars(template_path, output_path, label) do
    handlebars_args = ["--simple", template_path, "-f", output_path]

    command =
      case :os.type() do
        {:win32, _} -> ["cmd", ["/c", "handlebars"] ++ handlebars_args]
        _ -> ["handlebars", handlebars_args]
      end

    {time, result} = :timer.tc(System, :cmd, command)

    Debug.dbg_log(
      :verbose,
      "Created template #{label} in #{:erlang.float_to_binary(time / 1000, decimals: 1)}ms"
    )

    result
  end

  def compile_template(html, cache_path, label) do
    with {:ok, template_path} <- Temp.path(),
         :ok = File.write(template_path, html),
         {_output, 0} <- run_handlebars(template_path, cache_path, label),
         {:ok, template} <- File.read(cache_path) do
      {:ok, template}
    else
      e -> {:error, inspect(e)}
    end
  end
end
