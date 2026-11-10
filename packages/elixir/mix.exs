defmodule Tinyeval.MixProject do
  use Mix.Project

  # The package ships the repo's tinyeval unchanged: inside the repo, every mix command copies it into priv/.
  # A copy from Hex has it there already. The version is the one in the runner, so a release changes one line.
  @runner Path.expand("priv/tinyeval", __DIR__)

  if Path.basename(Path.dirname(__DIR__)) == "packages" do
    File.mkdir_p!(Path.dirname(@runner))
    File.cp!(Path.expand("../../tinyeval", __DIR__), @runner)
    File.cp!(Path.expand("../../LICENSE", __DIR__), Path.expand("LICENSE", __DIR__))
  end

  @version (case Regex.run(~r/^_te_version=(\S+)$/m, File.read!(@runner)) do
              [_, version] -> version
              nil -> Mix.raise("priv/tinyeval has no _te_version line")
            end)

  def project do
    [
      app: :tinyeval,
      version: @version,
      elixir: "~> 1.15",
      deps: [{:ex_doc, "~> 0.40", only: :dev, runtime: false}],
      description:
        "Test your app's AI calls with plain test cases, and run them with mix tinyeval.",
      package: [
        files: ~w(lib priv/tinyeval mix.exs README.md LICENSE),
        licenses: ["MIT"],
        links: %{
          "Website" => "https://tinyeval.com",
          "GitHub" => "https://github.com/evalship-hq/tinyeval",
          "Example" => "https://github.com/evalship-hq/elixir-llm-evals"
        }
      ],
      source_url: "https://github.com/evalship-hq/tinyeval",
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application, do: []
end
