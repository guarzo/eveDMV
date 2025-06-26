# Coverage configuration for ExCoveralls
# See: https://github.com/parroty/excoveralls

[
  minimum_coverage: 70,
  terminal_options: [
    file_column_width: 40
  ],
  skip_files: [
    # Skip test files
    "test/",
    # Skip generated files
    "_build/",
    "deps/",
    # Skip migration files
    "priv/repo/migrations",
    # Skip assets
    "assets/",
    "priv/static/",
    # Skip specific generated files
    "lib/eve_dmv_web/gettext.ex",
    "lib/eve_dmv_web/telemetry.ex"
  ],
  # Custom coverage thresholds for different modules
  coverage_options: [
    treat_no_relevant_lines_as_covered: true,
    output_dir: "cover/",
    template_path: "cover/custom.html.eex"
  ]
]
