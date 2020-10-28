defmodule ExLock.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :ex_lock,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/ndalmia/ex_lock/",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Postgres advisory lock backed elixir Library for locking critical section of code running on multiple machines.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Nishant Dalmia"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ndalmia/ex_lock"}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
