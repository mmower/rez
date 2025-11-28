defmodule Rez.AST.Pragma do
  @moduledoc """
  Specifies the Pragma AST node.

  Pragmas run at specific points during compilation, controlled by the `timing` field.
  Valid timings are:
  - `:after_build_schema` - Earliest point, before defaults are applied
  - `:after_schema_apply` - After defaults applied and schema validated
  - `:after_process_ast` - After all AST processing complete
  - `:before_create_runtime` - Just before JS generation begins
  - `:after_copy_assets` - Final point, for post-build tasks
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            name: "",
            timing: nil,
            built_in: false,
            values: [],
            script: nil,
            metadata: %{}

  alias __MODULE__
  alias Rez.Compiler.Compilation

  @valid_timings [
    :after_build_schema,
    :after_schema_apply,
    :after_process_ast,
    :before_create_runtime,
    :after_copy_assets
  ]

  @built_ins ["write_hierarchy"]

  def valid_timings, do: @valid_timings

  defmodule PluginAPI do
    use Lua.API, scope: "rez.plugin"

    deflua read_file(filename) do
      case File.read(filename) do
        {:ok, content} ->
          [true, content]

        {:error, error} ->
          [false, error]
      end
    end

    deflua write_file(filename, content) do
      case File.write(filename, content) do
        :ok ->
          true

        {:error, error} ->
          [false, error]
      end
    end

    deflua mkdir(path) do
      case File.mkdir_p(path) do
        :ok ->
          true

        {:error, error} ->
          [false, error]
      end
    end
  end

  def build(name, timing, values, position)
      when name in @built_ins and timing in @valid_timings do
    {:ok,
     %Pragma{
       position: position,
       name: name,
       timing: timing,
       values: values,
       built_in: true
     }}
  end

  def build(name, timing, values, position) when timing in @valid_timings do
    with {:ok, lua_script} <- File.read("pragmas/#{name}.lua") do
      {:ok,
       %Pragma{
         position: position,
         name: name,
         timing: timing,
         values: values,
         script: lua_script
       }}
    end
  end

  def build(_name, timing, _values, _position) do
    {:error, {:invalid_timing, timing}}
  end

  def run(
        %Pragma{built_in: true, name: "write_hierarchy", values: [file | _]},
        %Compilation{type_hierarchy: type_hierarchy} = compilation
      ) do
    case File.write(file, Apex.Format.format(type_hierarchy)) do
      :ok ->
        compilation

      {:error, errno} ->
        Compilation.add_error(
          compilation,
          "PRAGMA write_hierarchy: cannot write #{inspect(errno)}"
        )
    end
  end

  def run(%Pragma{name: _name, values: values, script: script}, compilation) do
    lua =
      Lua.new(sandboxed: [])
      |> Lua.load_api(Rez.AST.Pragma.PluginAPI)
      |> Lua.load_api(Rez.Compiler.Compilation.PluginAPI)
      |> Lua.load_api(Rez.AST.NodeHelper.PluginAPI)
      |> Lua.load_api(Rez.AST.Asset.PluginAPI)

    {encoded, lua} = Lua.encode!(lua, {:userdata, compilation})
    lua = Lua.set!(lua, [:compilation], encoded)
    lua = Lua.set!(lua, [:values], values)
    {result, _lua} = Lua.eval!(lua, script)

    [userdata: %Compilation{} = post_compilation] = result

    # IO.puts("RESULT")
    # Apex.ap(post_compilation)

    post_compilation
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Pragma do
  def node_type(_pragma), do: "pragma"
  def js_ctor(_pragma), do: raise("@pragma does not support a JS constructor!")
  def js_initializer(_pragma), do: raise("@pragma does not support a JS initializer!")
  def process(pragma, _resources), do: pragma
  def html_processor(_pragma, _attr), do: raise("@pragma does not support HTML processing!")
end
