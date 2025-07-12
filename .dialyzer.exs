# Dialyzer configuration for faster runs
# This file can override mix.exs settings when needed

[
  # Use all available cores for parallel analysis
  check_plt: false,

  # Skip analysis of test files in CI
  paths:
    case System.get_env("CI") do
      nil -> ["_build/#{Mix.env()}/lib/"]
      _ -> ["_build/#{Mix.env()}/lib/eve_dmv/ebin"]
    end,

  # Reduced warning types for speed while maintaining quality
  warnings: [
    :error_handling,
    :underspecs,
    :unknown,
    :unmatched_returns
  ],

  # Use incremental PLT updates
  halt_exit_status: true
]
