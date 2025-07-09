defmodule EveDmv.Database.MaterializedViewManager.ViewDefinitions do
  @moduledoc """
  Materialized view query definitions and configuration.

  Contains all the materialized view definitions including their queries,
  indexes, refresh strategies, and dependencies.
  """

  @doc """
  Get all materialized view definitions.
  """
  def all_views do
    [
      character_activity_summary(),
      system_activity_summary(),
      alliance_statistics(),
      daily_killmail_summary(),
      top_hunters_summary()
    ]
  end

  @doc """
  Find a view definition by name.
  """
  def find_view_by_name(view_name) do
    Enum.find(all_views(), &(&1.name == view_name))
  end

  @doc """
  Get view names that have a specific refresh strategy.
  """
  def views_by_strategy(strategy) do
    all_views()
    |> Enum.filter(&(&1.refresh_strategy == strategy))
    |> Enum.map(& &1.name)
  end

  @doc """
  Find views affected by changes to specific tables.
  """
  def find_affected_views(table_names) when is_list(table_names) do
    Enum.filter(all_views(), fn view_def ->
      Enum.any?(view_def.dependencies, fn dep -> dep in table_names end)
    end)
  end

  @doc """
  Extract table names from a cache invalidation pattern.
  """
  def extract_tables_from_pattern(pattern) do
    cond do
      String.contains?(pattern, "killmail") -> ["killmails_raw", "participants"]
      String.contains?(pattern, "character") -> ["participants"]
      String.contains?(pattern, "alliance") -> ["participants"]
      String.contains?(pattern, "system") -> ["killmails_raw"]
      true -> []
    end
  end

  # View Definitions

  defp character_activity_summary do
    %{
      name: "character_activity_summary",
      query: """
      SELECT
        character_id,
        character_name,
        COUNT(*) as total_killmails,
        COUNT(*) FILTER (WHERE NOT is_victim) as kills,
        COUNT(*) FILTER (WHERE is_victim) as losses,
        MAX(updated_at) as last_activity,
        MIN(updated_at) as first_activity,
        COUNT(DISTINCT DATE_TRUNC('month', updated_at)) as active_months,
        COUNT(DISTINCT alliance_id) as alliance_count,
        COUNT(DISTINCT corporation_id) as corp_count,
        COUNT(DISTINCT solar_system_id) as system_count
      FROM participants
      WHERE updated_at >= NOW() - INTERVAL '1 year'
      GROUP BY character_id, character_name
      HAVING COUNT(*) >= 5
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_character_activity_character_id ON character_activity_summary (character_id)",
        "CREATE INDEX IF NOT EXISTS idx_character_activity_last_activity ON character_activity_summary (last_activity DESC)",
        "CREATE INDEX IF NOT EXISTS idx_character_activity_kills ON character_activity_summary (kills DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants"]
    }
  end

  defp system_activity_summary do
    %{
      name: "system_activity_summary",
      query: """
      SELECT
        p.solar_system_id,
        ss.system_name,
        COUNT(*) as total_killmails,
        COUNT(DISTINCT p.character_id) as unique_characters,
        COUNT(DISTINCT p.alliance_id) as unique_alliances,
        COUNT(DISTINCT DATE_TRUNC('day', kr.killmail_time)) as active_days,
        MAX(kr.killmail_time) as last_activity
      FROM participants p
      JOIN killmails_raw kr ON p.killmail_id = kr.killmail_id
      LEFT JOIN eve_solar_systems ss ON p.solar_system_id = ss.system_id
      WHERE kr.killmail_time >= NOW() - INTERVAL '6 months'
      GROUP BY p.solar_system_id, ss.system_name
      HAVING COUNT(*) >= 10
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_system_activity_system_id ON system_activity_summary (solar_system_id)",
        "CREATE INDEX IF NOT EXISTS idx_system_activity_last_activity ON system_activity_summary (last_activity DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants", "killmails_raw", "eve_solar_systems"]
    }
  end

  defp alliance_statistics do
    %{
      name: "alliance_statistics",
      query: """
      SELECT
        p.alliance_id,
        p.alliance_name,
        COUNT(*) as total_killmails,
        COUNT(*) FILTER (WHERE NOT p.is_victim) as kills,
        COUNT(*) FILTER (WHERE p.is_victim) as losses,
        COUNT(DISTINCT p.character_id) as member_count,
        COUNT(DISTINCT p.corporation_id) as corp_count,
        COUNT(DISTINCT p.solar_system_id) as system_count,
        MAX(kr.killmail_time) as last_activity,
        COUNT(DISTINCT DATE_TRUNC('month', kr.killmail_time)) as active_months
      FROM participants p
      JOIN killmails_raw kr ON p.killmail_id = kr.killmail_id
      WHERE p.alliance_id IS NOT NULL
      AND kr.killmail_time >= NOW() - INTERVAL '1 year'
      GROUP BY p.alliance_id, p.alliance_name
      HAVING COUNT(*) >= 20
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_alliance_id ON alliance_statistics (alliance_id)",
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_last_activity ON alliance_statistics (last_activity DESC)",
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_member_count ON alliance_statistics (member_count DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants", "killmails_raw"]
    }
  end

  defp daily_killmail_summary do
    %{
      name: "daily_killmail_summary",
      query: """
      SELECT
        DATE_TRUNC('day', killmail_time) as activity_date,
        COUNT(*) as total_killmails,
        COUNT(DISTINCT solar_system_id) as systems_active
      FROM killmails_raw
      WHERE killmail_time >= NOW() - INTERVAL '3 months'
      GROUP BY DATE_TRUNC('day', killmail_time)
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_daily_summary_date ON daily_killmail_summary (activity_date DESC)"
      ],
      refresh_strategy: :incremental,
      dependencies: ["killmails_raw"]
    }
  end

  defp top_hunters_summary do
    %{
      name: "top_hunters_summary",
      query: """
      SELECT
        p.character_id,
        p.character_name,
        COUNT(*) as kill_count,
        COUNT(*) FILTER (WHERE p.final_blow) as final_blows,
        COUNT(DISTINCT p.solar_system_id) as hunting_systems,
        COUNT(DISTINCT p.ship_type_id) as ships_used,
        MAX(kr.killmail_time) as last_kill,
        RANK() OVER (ORDER BY COUNT(*) DESC) as kill_rank
      FROM participants p
      JOIN killmails_raw kr ON p.killmail_id = kr.killmail_id
      WHERE NOT p.is_victim
      AND kr.killmail_time >= NOW() - INTERVAL '6 months'
      GROUP BY p.character_id, p.character_name
      HAVING COUNT(*) >= 10
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_top_hunters_character_id ON top_hunters_summary (character_id)",
        "CREATE INDEX IF NOT EXISTS idx_top_hunters_kill_rank ON top_hunters_summary (kill_rank)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants", "killmails_raw"]
    }
  end
end
