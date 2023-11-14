defmodule Rez do
  alias Rez.Debug

  @moduledoc """
  `Rez` implements the command-line front end for the generator/compiler.
  """

  def version() do
    Application.spec(:rez, :vsn) |> to_string()
  end

  @default_options %{
    version: false,
    verbose: 0,
    wdir: nil,
    overwrite: false,
    ignore_missing_assets: false,
    output: true,
    write_source: false
  }

  @options [
    switches: [
      version: :boolean,
      wdir: :string,
      verbose: :integer,
      output: :string,
      overwrite: :boolean,
      author_name: :string,
      author_email: :string,
      game_title: :string,
      game_homepage: :string,
      ignore_missing_assets: :boolean,
      no_output: :boolean,
      write_source: :boolean
    ]
  ]

  def real_args(["rez_macos" | rest]) do
    rest
  end

  def real_args([_arg | rest]) do
    real_args(rest)
  end

  @dialyzer {:no_return, quit_fn: 1}
  def quit_fn(:halt) do
    fn code ->
      System.halt(code)
    end
  end

  def quit_fn(:exit) do
    fn code ->
      exit({:shutdown, code})
    end
  end

  def quit_fn(:quit) do
    fn _code -> IO.puts("SIMULATED QUIT") end
  end

  @dialyzer {:no_return, run_command: 2}
  def run_command(args, quit_method) do
    quit = quit_fn(quit_method)
    {options, args} = parse_options(args, @options, @default_options)

    if Map.get(options, :version, false) do
      IO.puts("rez v#{version()}")
    end

    Debug.start_link(options.verbose)

    if Enum.empty?(args) do
      IO.puts("No command specified")
      quit.(1)
    else
      [command | args] = args

      case command do
        "new" ->
          Rez.Generator.generate(args, options)
          quit.(0)

        "compile" ->
          case Rez.Compiler.compile(args, options) do
            :ok -> quit.(0)
            :error -> quit.(1)
          end

        "profile" ->
          quit = quit_fn(:quit)

          case Rez.Compiler.profile(args, options) do
            :ok -> quit.(0)
            :error -> quit.(1)
          end

        unknown ->
          IO.puts("Error: command '#{unknown}' not recognised.")
          quit.(1)
      end
    end
  end

  @doc """
  When built with Burrito, `start/2` is the program entry point.
  """
  @dialyzer {:no_return, start: 2}
  def start(_, _) do
    Burrito.Util.Args.get_arguments()
    |> real_args()
    |> run_command(:halt)
  end

  @doc """
  When built to run using escript the entry point is `main/1`
  """
  @dialyzer {:no_return, main: 1}
  def main(args) do
    run_command(args, :exit)
  end

  @doc """
  Returns a tuple {options, args} where options is a map dervied from the
  keyword list returned by the OptionParser module and applying the defaults
  supplied.
  """
  def parse_options(args, options, default_options) do
    {options_kwlst, parsed_args, _invalid} = OptionParser.parse(args, options)
    parsed_options = Map.merge(default_options, Map.new(options_kwlst))
    {parsed_options, parsed_args}
  end
end
