defmodule Rez.Compiler do
  @moduledoc """
  `Rez.Compiler` implements the compilation pipeline.

  The compiler is written as a pipeline based around a `Compilation`
  that stores inputs, outputs, progress, and errors.

  Each phase of the pipeline is a distinct module containing a function that
  takes a compilation, processes it, and returns a modified compilation.

  If a phase fails it should update the `Compilation` status to `:error` and
  add to the `errors` list, otherwise it should append updates to the
  `progress` list.

  It is expected that further phases do not run once the `Compilation` is in
  the `:error` state.

  See also: the Rez.Compiler.Config module
  """

  alias Rez.AST.NodeHelper
  alias Rez.AST.Pragma
  alias Rez.Compiler.Compilation
  import Rez.Debug

  # Mapping from phase modules to the pragma timing they trigger.
  # After running a phase in this map, all pragmas with the corresponding timing will be executed.
  @pragma_triggers %{
    Rez.Compiler.Phases.BuildSchema => :after_build_schema,
    Rez.Compiler.Phases.ApplySchema => :after_schema_apply,
    Rez.Compiler.Phases.ProcessAST => :after_process_ast,
    Rez.Compiler.Phases.InitializationOrder => :before_create_runtime,
    Rez.Compiler.Phases.CopyAssets => :after_copy_assets
  }

  @compiler_phases [
    Rez.Compiler.Phases.GetWorkingDirectory,
    Rez.Compiler.Phases.MakeDistPath,
    Rez.Compiler.Phases.MakeAssetPath,
    Rez.Compiler.Phases.MakeCachePath,
    Rez.Compiler.Phases.UpdateDeps,
    Rez.Compiler.Phases.CopyStdlib,
    Rez.Compiler.Phases.ReadSource,
    Rez.Compiler.Phases.ParseSource,
    Rez.Compiler.Phases.ConsolidateNodes,
    Rez.Compiler.Phases.CollectConstants,
    Rez.Compiler.Phases.ValidateMixins,
    Rez.Compiler.Phases.BuildSchema,
    # Pragmas with :after_build_schema timing run here
    Rez.Compiler.Phases.MapAliases,
    Rez.Compiler.Phases.ApplyDefaults,
    Rez.Compiler.Phases.ResolveConstants,
    Rez.Compiler.Phases.ApplySchema,
    # Pragmas with :after_schema_apply timing run here
    Rez.Compiler.Phases.CompileTemplates,
    Rez.Compiler.Phases.ProcessAST,
    # Pragmas with :after_process_ast timing run here (before ReprocessAST)
    Rez.Compiler.Phases.ReprocessAST,
    Rez.Compiler.Phases.InitializationOrder,
    # Pragmas with :before_create_runtime timing run here
    Rez.Compiler.Phases.DumpStructures,
    # Everything in the Game needs to be ready at this point
    Rez.Compiler.Phases.CreateRuntime,
    Rez.Compiler.Phases.WriteObjMap,
    Rez.Compiler.Phases.WriteGameFile,
    Rez.Compiler.Phases.CopyAssets,
    # Pragmas with :after_copy_assets timing run here
    Rez.Compiler.Phases.GenerateReports
  ]

  def run_phase(phase, compilation) do
    v_log("Running phase: #{to_string(phase)}")
    compilation = apply(phase, :run_phase, [compilation])

    compilation =
      if compilation.content && length(compilation.content) > 0 do
        # Assuming there is content, automatically (re-)build the
        # id & type mappings after each phase has modified the content
        %{
          compilation
          | type_map: NodeHelper.build_type_map(compilation.content),
            id_map: NodeHelper.build_id_map(compilation.content)
        }
      else
        compilation
      end

    # Check if this phase triggers any pragmas
    run_triggered_pragmas(phase, compilation)
  end

  defp run_triggered_pragmas(phase, %Compilation{status: :ok, pragmas: pragmas} = compilation)
       when is_list(pragmas) do
    case Map.get(@pragma_triggers, phase) do
      nil ->
        compilation

      timing ->
        v_log("Running pragmas with timing: #{timing}")

        pragmas
        |> Enum.filter(fn %Pragma{timing: t} -> t == timing end)
        |> Enum.reduce(compilation, fn pragma, comp ->
          Pragma.run(pragma, comp)
        end)
    end
  end

  defp run_triggered_pragmas(_phase, compilation), do: compilation

  def dbg_run_phase(phase, compilation) do
    {time, result} = :timer.tc(__MODULE__, :run_phase, [phase, compilation])
    d_log("Elapsed time #{:erlang.float_to_binary(time / 1_000_000, decimals: 1)}s")
    result
  end

  def compile(args, options) when is_list(args) and is_map(options) do
    if Enum.empty?(args) do
      e_log("Error: no files specified to compile.")
      exit(:shutdown)
    end

    runner =
      case dbg_do?(:debug) do
        true -> &dbg_run_phase/2
        false -> &run_phase/2
      end

    source_path = List.first(args)

    %Compilation{status: status} =
      Enum.reduce(
        @compiler_phases,
        %Compilation{source_path: source_path, options: options},
        runner
      )

    status
  end

  def profile(args, options) do
    IO.puts("Profiling run")

    # Ignore the file reading times
    compilation = %Compilation{source_path: List.first(args), options: options}
    compilation = run_phase(Rez.Compiler.ReadSource, compilation)

    # Warm it up
    IO.puts("Warm up")
    run_phase(Rez.Compiler.ParseSource, compilation)

    # Now profile it
    IO.puts("Profiling")
    :fprof.trace(:start)
    compilation = run_phase(Rez.Compiler.ParseSource, compilation)
    :fprof.trace(:stop)
    :fprof.profile()

    IO.puts("Writing analysis")
    :fprof.analyse(dest: ~c"fprof_analysis.txt")

    data = :file.consult("fprof_analysis.txt")
    File.write!("fprof_analysis.ans", Apex.Format.format(data))

    Map.get(compilation, :status)
  end
end
