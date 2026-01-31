defmodule FHIR.MixProject do
  use Mix.Project

  def project do
    [
      app: :fhir,
      version: "0.1.0",
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ]
    ]
  end

  def cli do
    [
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        "test.watch": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {FHIR.Application, []},
      extra_applications: [:logger, :finch]
    ]
  end

  # After updating, you must run the deps.nix mix task
  # mix do deps.get + deps.nix
  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:finch, "~> 0.13"},
      {:jason, "~> 1.2"}
    ]
  end
end
