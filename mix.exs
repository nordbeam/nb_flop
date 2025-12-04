defmodule NbFlop.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nordbeam/nb_flop"

  def project do
    [
      app: :nb_flop,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      name: "NbFlop",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core dependency
      {:flop, "~> 0.26"},

      # Installer framework
      {:igniter, "~> 0.7", optional: true},

      # Optional integrations (use path for local development)
      {:nb_serializer, path: "../nb_serializer", optional: true, override: true},
      {:nb_inertia, path: "../nb_inertia", optional: true, runtime: false},

      # Phoenix for token generation (optional)
      {:phoenix, "~> 1.7", optional: true},

      # CSV export (optional)
      {:csv, "~> 3.2", optional: true},

      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Flop integration for the nb ecosystem. Provides serializers for Flop pagination metadata
    and React components for pagination, sorting, and filtering. Works seamlessly with
    nb_serializer, nb_inertia, and nb_ts for full-stack type safety.
    """
  end

  defp package do
    [
      name: "nb_flop",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
        lib
        priv
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
        .formatter.exs
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
