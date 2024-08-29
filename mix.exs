defmodule Rez.MixProject do
  use Mix.Project

  @version "1.3.0"

  def project do
    [
      app: :rez,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Rez]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex, :crypto, :iex, :tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ergo, "~> 0.9"},
      # {:ergo, path: "/Users/matt/Projects/Elixir/ergo"},
      {:logical_file, "~> 1.0"},
      # {:logical_file, path: "/Users/matt/Projects/Elixir/logical_file"},
      # {:mix_test_watch, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.2"},
      {:temp, "~> 0.4"},
      {:ex_image_info, "~> 0.2.4"},
      {:inflectorex, "~> 0.1.2"},
      {:burrito, "~> 1.0"},
      {:mime, "~> 2.0"},
      {:rename, "~> 0.1.0"},
      {:poison, "~> 5.0"},
      {:dialyxir, "~> 1.3", runtime: false},
      {:apex, "~>1.2.1"},
      {:floki, "~> 0.36.2"}
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
