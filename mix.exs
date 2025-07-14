defmodule EveDmv.MixProject do
  use Mix.Project

  def project do
    [
      app: :eve_dmv,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      excoveralls: [
        minimum_coverage: 4.0,
        output_dir: "cover",
        skip_files: [
          # Test files
          "test/",
          # Generated files
          "_build/",
          "deps/",
          # Configuration files
          "config/",
          # Migration files (infrastructure, not business logic)
          "priv/repo/migrations/",
          # Mock and test support files
          "test/support/",
          # Auto-generated files
          "lib/eve_dmv_web/gettext.ex",
          "lib/eve_dmv_web/endpoint.ex"
        ],
        stop_on_missing_beam_file: false,
        treat_no_relevant_lines_as_covered: true
      ],
      # Dialyzer configuration - optimized for speed
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        plt_core_path: "priv/plts/core.plt",
        list_unused_filters: true,
        # Reduced flags for faster analysis while keeping essential checks
        flags: [:error_handling, :underspecs],
        # Skip analysis of test files to speed up CI
        paths: ["_build/#{Mix.env()}/lib/eve_dmv/ebin"],
        # Use incremental analysis
        check_plt: false,
        # Ignore warnings from dependencies
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      # Documentation configuration
      docs: [
        main: "EveDmv",
        name: "EVE DMV",
        source_url: "https://github.com/wanderer-industries/eve-dmv",
        homepage_url: "https://github.com/wanderer-industries/eve-dmv",
        extras: [
          "README.md",
          "CLAUDE.md": [title: "Development Guide"]
        ],
        groups_for_modules: [
          "Intelligence Analysis": [
            EveDmv.Intelligence,
            EveDmv.Intelligence.AnalysisCache,
            EveDmv.Intelligence.IntelligenceCache,
            EveDmv.Intelligence.IntelligenceCoordinator,
            EveDmv.Intelligence.CharacterAnalysis,
            EveDmv.Intelligence.WhSpace,
            EveDmv.Intelligence.CorrelationEngine
          ],
          "Killmail Processing": [
            EveDmv.Killmails,
            EveDmv.Killmails.KillmailPipeline,
            EveDmv.Killmails.SSEProducer,
            EveDmv.Killmails.MockSSEServer
          ],
          "Market Data": [
            EveDmv.Market,
            EveDmv.Market.JaniceClient,
            EveDmv.Market.MutamarketClient,
            EveDmv.Market.PriceCache,
            EveDmv.Market.RateLimiter
          ],
          "EVE API Integration": [
            EveDmv.Eve,
            EveDmv.Eve.EsiClient,
            EveDmv.Eve.EsiUtils,
            EveDmv.Eve.NameResolver,
            EveDmv.Eve.StaticDataLoader
          ],
          Configuration: [
            EveDmv.Config,
            EveDmv.Config.Cache,
            EveDmv.Config.Http,
            EveDmv.Config.RateLimit,
            EveDmv.Config.CircuitBreaker,
            EveDmv.Config.Pipeline,
            EveDmv.Config.Api
          ],
          "Database & Resources": [
            EveDmv.Api,
            EveDmv.Database,
            EveDmv.Enrichment,
            EveDmv.Users,
            EveDmv.Characters,
            EveDmv.Corporations
          ],
          "Web Interface": [
            EveDmvWeb,
            EveDmvWeb.Endpoint,
            EveDmvWeb.Router,
            EveDmvWeb.AuthLive,
            EveDmvWeb.CoreComponents
          ],
          Utilities: [
            EveDmv.Utils,
            EveDmv.Utils.Cache,
            EveDmv.Utils.MathUtils,
            EveDmv.Utils.KillmailUtils
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {EveDmv.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:exsync, "~> 0.4", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2"},
      {:bandit, "~> 1.5"},

      # WebSocket client for Wanderer integration
      {:websockex, "~> 0.4.3"},
      {:slipstream, "~> 1.2"},

      # Ash Framework
      {:ash, "~> 3.4"},
      {:ash_postgres, "~> 2.4"},
      {:ash_phoenix, "~> 2.1"},
      {:ash_json_api, "~> 1.4"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.1"},

      # Additional dependencies for EVE integration
      {:req, "~> 0.4"},
      {:broadway, "~> 1.1"},
      {:cachex, "~> 4.1"},
      {:gun, "~> 2.0"},
      {:httpoison, "~> 2.0"},
      {:dotenvy, "~> 1.1"},
      {:nimble_csv, "~> 1.2"},
      # For native bzip2 decompression (requires libbz2-dev/bzip2-dev system package)
      {:bzip2, "~> 0.3.0"},
      {:cowboy, "~> 2.9", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      # Documentation
      {:ex_doc, "~> 0.32", only: :dev, runtime: false},
      # Additional test dependencies for comprehensive testing
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      # SAT solver for Ash framework (fast C-based solver)
      {:picosat_elixir, "~> 0.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.coverage": ["coveralls.html"],
      "test.coverage.console": ["coveralls"],
      "test.coverage.json": ["coveralls.json"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind eve_dmv", "esbuild eve_dmv"],
      "assets.deploy": [
        "tailwind eve_dmv --minify",
        "esbuild eve_dmv --minify",
        "phx.digest"
      ],
      # Quality assurance aliases
      "quality.check": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "deps.audit",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer.fast",
        "docs.check"
      ],
      # Fast dialyzer for CI/development
      "dialyzer.fast": ["cmd ./scripts/fast_dialyzer.sh"],
      "dialyzer.full": ["cmd ./scripts/fast_dialyzer.sh --rebuild-plt"],
      "quality.parallel": ["cmd ./scripts/parallel_quality_check.sh"],
      "quality.fix": [
        "format",
        "deps.clean --unused",
        "deps.get"
      ],
      # Documentation aliases
      "docs.check": ["docs"],
      "docs.build": ["docs"],
      "docs.open": ["docs", "cmd open doc/index.html"]
    ]
  end
end
