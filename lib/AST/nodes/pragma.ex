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

  alias Rez.AST.NodeHelper
  alias __MODULE__
  alias Rez.Compiler.Compilation

  @valid_timings [
    :after_build_schema,
    :after_schema_apply,
    :after_process_ast,
    :before_create_runtime,
    :after_copy_assets
  ]

  @built_ins ["write_content", "write_id_map", "write_hierarchy", "write_obj_map"]

  def valid_timings, do: @valid_timings

  defmodule PluginAPI do
    use Lua.API, scope: "rez.plugin"

    deflua run(cmd, args), state do
      args = Lua.decode!(state, args) |> Enum.map(fn {_, arg} -> arg end)
      {result, exit_status} = System.cmd(cmd, args)

      if exit_status == 0 do
        result
      else
        Lua.encode_list!(state, [nil, exit_status])
      end

      result
    end

    deflua cwd(), state do
      case File.cwd() do
        {:ok, cwd} ->
          cwd

        {:error, reason} ->
          Lua.encode_list!(state, [nil, reason])
      end
    end

    deflua ls(path), state do
      case File.ls(path) do
        {:ok, files} ->
          Lua.encode_list!(state, [files])

        {:error, reason} ->
          Lua.encode_list!(state, [nil, reason])
      end
    end

    deflua read_file(filename), state do
      case File.read(filename) do
        {:ok, content} ->
          content

        {:error, reason} ->
          Lua.encode_list!(state, [nil, reason])
      end
    end

    deflua write_file(filename, content), state do
      case File.write(filename, content) do
        :ok ->
          true

        {:error, reason} ->
          Lua.encode_list!(state, [nil, reason])
      end
    end

    deflua mkdir(path), state do
      case File.mkdir_p(path) do
        :ok ->
          true

        {:error, reason} ->
          Lua.encode_list!(state, [nil, reason])
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

  def run(
        %Pragma{built_in: true, name: "write_content", values: [file | _]},
        %Compilation{content: content} = compilation
      ) do
    case File.write(file, "content = " <> inspect(content, pretty: true, limit: :infinity)) do
      :ok ->
        compilation

      {:error, errno} ->
        Compilation.add_error(
          compilation,
          "PRAGMA write_content: cannot write '#{file}' error: #{inspect(errno)}"
        )
    end
  end

  def run(
        %Pragma{built_in: true, name: "write_id_map", values: [file | _]},
        %Compilation{id_map: id_map} = compilation
      ) do
    case File.write(file, "id_map = " <> inspect(id_map, pretty: true, limit: :infinity)) do
      :ok ->
        compilation

      {:error, errno} ->
        Compilation.add_error(
          compilation,
          "PRAGMA write_id_map: cannot write '#{file}' error: #{inspect(errno)}"
        )
    end
  end

  def run(
        %Pragma{built_in: true, name: "write_obj_map"},
        %Compilation{content: content} = compilation
      ) do
    content
    |> Enum.filter(fn node ->
      !NodeHelper.get_attr_value(node, "$built_in", false)
    end)
    |> Enum.group_by(&PrintableGroup.node_type/1)
    |> Enum.filter(&PrintableGroup.printable_group/1)
    |> Enum.each(&PrintableGroup.print_group/1)

    compilation
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

defmodule PrintableGroup do
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.AST.Patch

  def printable_group({{"script", _}, _}), do: false
  def printable_group({{"style", _}, _}), do: false
  def printable_group(_), do: true

  def print_group({{type, nil}, nodes_of_type}) do
    IO.puts("--[#{type} (#{Enum.count(nodes_of_type)})]----")
    Enum.each(nodes_of_type, &print_node/1)
    IO.puts("")
  end

  def print_group({{type, alias}, nodes_of_type}) do
    IO.puts("--[#{alias} -> #{type} (#{Enum.count(nodes_of_type)})]----")
    Enum.each(nodes_of_type, &print_node/1)
    IO.puts("")
  end

  def print_node(%Patch{} = patch) do
    case Patch.type(patch) do
      :function -> IO.puts("@patch #{Patch.object(patch)}.#{Patch.function(patch)}")
      :method -> IO.puts("@patch #{Patch.object(patch)}.#{Patch.method(patch)}")
    end
  end

  def print_node(%{id: id} = node) do
    {file, line, _col} = node.position
    file = Path.relative_to_cwd(file)
    IO.puts("#{node_type_name(node)} ##{id} — #{file}:#{line}")
  end

  def print_node(_) do
  end

  def node_type_name(node) do
    NodeHelper.get_attr_value(node, "$alias", Node.node_type(node))
  end

  def node_type(node) do
    {Node.node_type(node), NodeHelper.get_attr_value(node, "$alias")}
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Pragma do
  def node_type(_pragma), do: "pragma"
  def js_ctor(_pragma), do: raise("@pragma does not support a JS constructor!")
  def js_initializer(_pragma), do: raise("@pragma does not support a JS initializer!")
  def process(pragma, _resources), do: pragma
  def html_processor(_pragma, _attr), do: raise("@pragma does not support HTML processing!")
end
