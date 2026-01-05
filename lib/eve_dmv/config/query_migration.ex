defmodule EveDmv.Config.QueryMigration do
  @moduledoc """
  Feature flags for gradual migration from raw SQL to Ash queries.

  This module provides configuration settings to control the rollout of
  Ash-based query implementations, allowing for:

  - Gradual migration with feature flags
  - A/B testing between old and new implementations
  - Comparison logging to validate correctness
  - Easy rollback if issues are discovered

  ## Completed Migrations

  The following migrations have been completed and the Ash implementations
  are now the only implementations:

  - `CharacterStats.calculate_for_character/2` - Character kill/death statistics
  - `StatsLoader.load_stats/2` - Corporation statistics

  ## Configuration

  Environment variables:
  - `EVE_DMV_QUERY_MIGRATION_USE_ASH_KILLMAIL_QUERIES` - Enable Ash killmail queries
  - `EVE_DMV_QUERY_MIGRATION_USE_ASH_PARTICIPANT_QUERIES` - Enable Ash participant queries
  - `EVE_DMV_QUERY_MIGRATION_LOG_COMPARISON_MISMATCHES` - Log when old/new differ

  Config file (config/config.exs):
      config :eve_dmv, :query_migration,
        use_ash_killmail_queries: false,
        use_ash_participant_queries: false,
        log_comparison_mismatches: true
  """

  alias EveDmv.Config.UnifiedConfig

  @doc """
  Check if Ash-based killmail queries should be used.

  When enabled, killmail lookups will use the enhanced KillmailRaw
  aggregates and calculations instead of raw SQL queries.

  Environment: `EVE_DMV_QUERY_MIGRATION_USE_ASH_KILLMAIL_QUERIES`
  Default: `false`
  """
  @spec use_ash_killmail_queries?() :: boolean()
  def use_ash_killmail_queries? do
    get_flag(:use_ash_killmail_queries, false)
  end

  @doc """
  Check if Ash-based participant queries should be used.

  When enabled, participant activity summaries will use the new
  Ash-based actions instead of raw SQL queries.

  Environment: `EVE_DMV_QUERY_MIGRATION_USE_ASH_PARTICIPANT_QUERIES`
  Default: `false`
  """
  @spec use_ash_participant_queries?() :: boolean()
  def use_ash_participant_queries? do
    get_flag(:use_ash_participant_queries, false)
  end

  @doc """
  Check if comparison logging is enabled.

  When enabled, the system will run both old and new query implementations
  and log any mismatches between their results. This is useful for
  validating that the Ash implementations produce identical results
  to the raw SQL implementations.

  Note: This adds overhead and should only be enabled during migration
  validation phases.

  Environment: `EVE_DMV_QUERY_MIGRATION_LOG_COMPARISON_MISMATCHES`
  Default: `false`
  """
  @spec log_comparison_mismatches?() :: boolean()
  def log_comparison_mismatches? do
    get_flag(:log_comparison_mismatches, false)
  end

  @doc """
  Check if shadow mode is enabled.

  In shadow mode, the system runs the new Ash implementation alongside
  the old SQL implementation but returns results from the old implementation.
  This allows testing the new implementation without affecting users.

  Environment: `EVE_DMV_QUERY_MIGRATION_SHADOW_MODE`
  Default: `false`
  """
  @spec shadow_mode?() :: boolean()
  def shadow_mode? do
    get_flag(:shadow_mode, false)
  end

  @doc """
  Get the sample rate for comparison logging (0.0 to 1.0).

  When comparison logging is enabled, this controls what percentage of
  requests actually run the comparison. A value of 0.1 means 10% of
  requests will be compared.

  This helps reduce overhead during high-traffic periods while still
  catching issues.

  Environment: `EVE_DMV_QUERY_MIGRATION_COMPARISON_SAMPLE_RATE`
  Default: `1.0` (100% when comparison logging is enabled)
  """
  @spec comparison_sample_rate() :: float()
  def comparison_sample_rate do
    rate = get_flag(:comparison_sample_rate, 1.0)

    cond do
      is_float(rate) -> rate
      is_integer(rate) -> rate / 1.0
      true -> 1.0
    end
  end

  @doc """
  Get all migration flags as a map.

  Useful for debugging and displaying current migration state.
  Completed migrations (character stats, corporation stats) always return true.
  """
  @spec all_flags() :: map()
  def all_flags do
    %{
      # Completed migrations - always true
      use_ash_character_stats: true,
      use_ash_corporation_stats: true,
      # Pending migrations - controlled by feature flags
      use_ash_killmail_queries: use_ash_killmail_queries?(),
      use_ash_participant_queries: use_ash_participant_queries?(),
      log_comparison_mismatches: log_comparison_mismatches?(),
      shadow_mode: shadow_mode?(),
      comparison_sample_rate: comparison_sample_rate()
    }
  end

  @doc """
  Check if any migration flags are enabled.

  Returns true if at least one Ash query migration is active.
  Note: Character stats and corporation stats migrations are complete
  and always return true.
  """
  @spec any_migrations_active?() :: boolean()
  def any_migrations_active? do
    # Character and corporation stats are always active (migration complete)
    true
  end

  # Private helper to get flag value with proper precedence
  @spec get_flag(atom(), any()) :: any()
  defp get_flag(flag_name, default) do
    # First try unified config path
    unified_value = UnifiedConfig.get([:query_migration, flag_name])

    if unified_value != nil do
      unified_value
    else
      # Fall back to direct application config
      config = Application.get_env(:eve_dmv, :query_migration, [])
      Keyword.get(config, flag_name, default)
    end
  end
end
