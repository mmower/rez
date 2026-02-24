defmodule Rez.Compiler.Phases.CreateRuntime do
  @moduledoc """
  `Rez.Compiler.CreateRuntime` implements the compiler phase that generates
  the contents of the Rez JS runtime.
  """

  require EEx

  alias Rez.Compiler.IOError
  alias Rez.Compiler.Compilation

  alias Rez.AST.NodeHelper

  alias Rez.AST.Asset
  alias Rez.AST.TypeHierarchy

  alias Rez.AST.ValueEncoder

  @js_stdlib_dir "assets/templates/runtime"
  @js_stdlib_files Path.join([@js_stdlib_dir, "rez_*.js"])
                   |> Path.wildcard()
                   |> Enum.sort()
                   |> Enum.map(&Path.expand/1)
  for file <- @js_stdlib_files, do: @external_resource(file)
  @js_stdlib Enum.map_join(@js_stdlib_files, "\n", &File.read!/1)

  EEx.function_from_file(
    :def,
    :init_game_objects,
    Path.expand("assets/templates/runtime/init_game_objects.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :patch_js_objects,
    Path.expand("assets/templates/runtime/patch_js_objects.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :register_expression_filters,
    Path.expand("assets/templates/runtime/register_expression_filters.js.eex"),
    [:assigns]
  )

  def generate_constants(constants) when is_map(constants) do
    Enum.map_join(constants, "\n", fn {name, {type, value}} ->
      js_value = ValueEncoder.encode_value({type, value})
      ~s|window.$#{name} = #{js_value};|
    end)
  end

  EEx.function_from_file(
    :def,
    :bind_keys,
    Path.expand("assets/templates/runtime/bind_keys.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :user_components,
    Path.expand("assets/templates/runtime/user_components.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :mixins,
    Path.expand("assets/templates/runtime/mixins.js.eex"),
    [:assigns]
  )

  EEx.function_from_file(
    :def,
    :render_runtime,
    Path.expand("assets/templates/runtime.js.eex"),
    [
      :assigns
    ]
  )

  @doc """
  Runs the game runtime template over the Game AST node.
  """
  def run_phase(
        %Compilation{
          status: :ok,
          content: content,
          id_map: id_map,
          type_map: type_map,
          constants: constants,
          dist_path: dist_path,
          progress: progress,
          options: %{output: true}
        } = compilation
      ) do
    {_game, game_elements, _aux_elements} = NodeHelper.partition_elements(content)

    game = id_map["game"]
    assets = Map.get(type_map, "asset", [])
    patches = Map.get(type_map, "patch", [])
    keybindings = Map.get(type_map, "keybinding", [])
    user_components = Map.get(type_map, "component", [])
    mixins = Map.get(type_map, "mixin", [])
    generators = Map.get(type_map, "generator", [])
    filters = Map.get(type_map, "filter", [])

    runtime_code =
      render_runtime(
        js_stdlib: @js_stdlib,
        js_userlib: js_userlib_content(assets),
        constants: generate_constants(constants),
        type_hierarchy: TypeHierarchy.to_json(compilation.type_hierarchy),
        patch_js_objects: patch_js_objects(patches: patches),
        bind_keys: bind_keys(keybindings: keybindings),
        user_components: user_components(user_components: user_components),
        mixins: mixins(mixins: mixins),
        init_game_objects:
          init_game_objects(game: game, game_elements: game_elements, generators: generators),
        register_expression_filters: register_expression_filters(filters: filters)
      )

    output_path = Path.join(dist_path, "assets/js/runtime.js")
    File.mkdir_p(Path.dirname(output_path))

    case File.write(output_path, runtime_code) do
      :ok -> %{compilation | progress: ["Written runtime to #{output_path}" | progress]}
      {:error, code} -> IOError.file_write_error(compilation, code, "runtime.js", output_path)
    end
  end

  def run_phase(compilation) do
    compilation
  end

  def js_userlib_content(assets) do
    assets
    |> Enum.filter(fn node ->
      NodeHelper.instance_node?(node) && NodeHelper.get_attr_value(node, "$js_runtime", false)
    end)
    |> Enum.map_join("\n\n", &Asset.read_source/1)
  end
end
