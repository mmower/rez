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

  alias Rez.Compiler.Compilation
  import Rez.Debug

  @compiler_phases [
    Rez.Compiler.GetWorkingDirectory,
    Rez.Compiler.MakeDistPath,
    Rez.Compiler.MakeAssetPath,
    Rez.Compiler.MakeCachePath,
    Rez.Compiler.UpdateDeps,
    Rez.Compiler.CopyStdlib,
    Rez.Compiler.ReadSource,
    Rez.Compiler.ParseSource,
    Rez.Compiler.ValidateNodes,
    Rez.Compiler.ProcessAST,
    Rez.Compiler.NodeCheck,
    # Everything in the Game needs to be ready at this point
    Rez.Compiler.CreateRuntime,
    Rez.Compiler.WriteObjMap,
    Rez.Compiler.WriteGameFile,
    Rez.Compiler.CopyAssets,
    Rez.Compiler.Reports
  ]

  def run_phase(phase, compilation) do
    v_log("Running phase: #{to_string(phase)}")
    apply(phase, :run_phase, [compilation])
  end

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
