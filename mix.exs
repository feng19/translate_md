defmodule TranslateMd.MixProject do
  use Mix.Project

  def project do
    [
      app: :translate_md,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: ["escript.build": :prod]]
  end

  def escript do
    [
      main_module: TranslateMd.CLI,
      name: "translate_md"
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
