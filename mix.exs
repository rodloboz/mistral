defmodule Mistral.MixProject do
  use Mix.Project

  def project do
    [
      app: :mistral,
      name: "Mistral",
      description: "A nifty little library for working with Mistral in Elixir.",
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "Mistral"
      ],
      package: [
        name: "mistral",
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/rodloboz/mistral-ex"
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.6", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.16", only: :test},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:nimble_options, "~> 1.1"},
      {:plug, "~> 1.16"},
      {:req, "~> 0.5"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]
end
