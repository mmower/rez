defmodule Rez.MixProject do
  use Mix.Project

  @version "0.9.2"

  def project do
    case System.get_env("BUILD_MODE") do
      "burrito" ->
        [
          app: :rez,
          version: @version,
          elixir: "~> 1.13",
          start_permanent: Mix.env() == :prod,
          deps: deps(),
          releases: releases()
        ]

      _ ->
        [
          app: :rez,
          version: @version,
          elixir: "~> 1.13",
          start_permanent: Mix.env() == :prod,
          deps: deps(),
          escript: [main_module: Rez]
        ]
    end
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    case System.get_env("BUILD_MODE") do
      "burrito" ->
        [
          mod: {Rez, []},
          extra_applications: [:logger, :eex, :crypto, :iex]
        ]

      _ ->
        [
          extra_applications: [:logger, :eex, :crypto, :iex]
        ]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:earmark, "~> 1.4"},
      {:ergo, "~> 0.9"},
      # {:ergo, path: "/Users/matt/Projects/Elixir/ergo"},
      {:logical_file, "~> 1.0"},
      # {:logical_file, path: "/Users/matt/Projects/Elixir/logical_file"},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.2"},
      {:temp, "~> 0.4"},
      {:ex_image_info, "~> 0.2.4"},
      {:inflectorex, "~> 0.1.2"},
      {:burrito, github: "burrito-elixir/burrito", branch: "digit/epmd-shim"},
      {:mime, "~> 2.0"},
      {:rename, "~> 0.1.0"},
      {:poison, "~> 5.0"}
    ]
  end

  def rez_version() do
    @version
  end

  def releases() do
    [
      rez: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
