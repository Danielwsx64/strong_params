defmodule StrongParams.MixProject do
  use Mix.Project

  def project do
    [
      app: :strong_params,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

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
end
