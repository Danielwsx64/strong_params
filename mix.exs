defmodule StrongParams.MixProject do
  use Mix.Project

  @version "0.0.1"
  @description "Filter request parameters in a Phoenix app"
  @links %{"GitHub" => "https://github.com/Danielwsx64/strong_params"}

  def project do
    [
      app: :strong_params,
      version: @version,
      description: @description,
      source_url: @links["GitHub"],
      package: package(),
      elixir: "~> 1.10",
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
      {:phoenix, " ~> 1.5", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: @links
    ]
  end
end
