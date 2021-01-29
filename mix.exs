defmodule StrongParams.MixProject do
  use Mix.Project

  @version "0.0.4"
  @description "Filter request parameters in a Phoenix app"
  @links %{"GitHub" => "https://github.com/brainnco/strong_params"}

  def project do
    [
      app: :strong_params,
      version: @version,
      description: @description,
      source_url: @links["GitHub"],
      package: package(),
      docs: docs(),
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:deep_merge, " ~> 1.0"},
      {:plug, " ~> 1.11"},

      # Dev/Test dependencies

      {:phoenix, " ~> 1.5", only: :test},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: @links
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md": [title: "Get starting"]
      ],
      groups_for_modules: []
    ]
  end
end
