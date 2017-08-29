defmodule BuildClient.Mixfile do
  use Mix.Project

  def project do
    [app: :build_client,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "AX Deployment Client",
     package: package,
     escript: [main_module: BuildClient.CLI],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
     mod: {BuildClient, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    []
  end

  defp package do
    [
      files: ["lib", "mix.exs"],
      maintainers: ["Dmitry A Pyatkov"],
      licences: ["Can be used under FREE Licence for any purpose whatsoever."],
      links: %{"GitHub" => "https://github.com/dapdizzy/build_client"}
    ]
  end
end
