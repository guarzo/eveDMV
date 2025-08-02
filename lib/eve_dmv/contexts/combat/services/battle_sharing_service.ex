defmodule EveDmv.Contexts.Combat.Services.BattleSharingService do
  @moduledoc """
  Service for sharing battle reports and analysis.

  Handles:
  - Generating shareable battle reports
  - Creating battle permalinks
  - Exporting battle data in various formats
  - Managing battle visibility and access
  """

  alias EveDmv.Contexts.Combat.Core.BattleAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer
  alias EveDmv.Contexts.Combat.Services.BattleService
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Utils.NumberFormatter
  require Ash.Query

  require Logger

  @share_token_length 16
  @share_url_base "https://evedmv.com/battles/"

  @doc """
  Share a battle by creating a shareable link.
  """
  def share_battle(battle_id, sharing_options \\ %{}) do
    with {:ok, battle} <- BattleService.get_battle(battle_id),
         {:ok, share_token} <- generate_share_token(battle),
         {:ok, _} <- update_battle_sharing_info(battle, share_token, sharing_options) do
      share_url = build_share_url(share_token)

      {:ok,
       %{
         share_url: share_url,
         share_token: share_token,
         expires_at: calculate_expiry(sharing_options),
         options: sharing_options
       }}
    end
  end

  @doc """
  Generate a battle report in various formats.
  """
  def generate_battle_report(battle_id, format \\ :markdown) do
    with {:ok, battle} <- BattleService.get_battle(battle_id),
         {:ok, analysis} <- BattleAnalyzer.analyze_battle(battle_id) do
      report =
        case format do
          :markdown -> generate_markdown_report(battle, analysis)
          :json -> generate_json_report(battle, analysis)
          :html -> generate_html_report(battle, analysis)
          :text -> generate_text_report(battle, analysis)
          _ -> {:error, :unsupported_format}
        end

      {:ok, report}
    end
  end

  @doc """
  Export battle data for external tools.
  """
  def export_battle_data(battle_id, export_options \\ %{}) do
    with {:ok, battle} <- BattleService.get_battle(battle_id),
         {:ok, export_data} <- prepare_export_data(battle, export_options) do
      format = Map.get(export_options, :format, :json)

      formatted_data =
        case format do
          :json -> Jason.encode!(export_data, pretty: true)
          :csv -> export_to_csv(export_data)
          :zkillboard -> format_for_zkillboard(export_data)
          _ -> {:error, :unsupported_export_format}
        end

      {:ok, formatted_data}
    end
  end

  @doc """
  Create a battle summary card for embedding.
  """
  def create_battle_card(battle_id, card_options \\ %{}) do
    with {:ok, battle} <- BattleService.get_battle(battle_id),
         {:ok, summary} <- BattleAnalyzer.get_battle_summary(battle_id) do
      card = %{
        title: build_battle_title(battle, summary),
        description: summary.headline,
        stats: format_key_stats(summary.key_stats),
        participants: %{
          total: battle.participant_count,
          breakdown: get_participant_breakdown(battle_id)
        },
        value: format_isk_value(battle.total_value),
        duration: format_duration(battle.duration_minutes),
        embed_code: generate_embed_code(battle_id, card_options),
        preview_image: generate_preview_image_url(battle_id)
      }

      {:ok, card}
    end
  end

  @doc """
  Get battle by share token.
  """
  def get_shared_battle(share_token) do
    with {:ok, battle} <- find_battle_by_token(share_token),
         :ok <- verify_share_access(battle) do
      {:ok, battle}
    end
  end

  @doc """
  Revoke battle sharing.
  """
  def revoke_sharing(battle_id) do
    with {:ok, _battle} <- BattleService.get_battle(battle_id) do
      BattleService.update_battle(battle_id, %{
        share_token: nil,
        share_expires_at: nil,
        sharing_enabled: false
      })
    end
  end

  @doc """
  Generate a battle comparison report.
  """
  def generate_comparison_report(battle_ids) when is_list(battle_ids) do
    with {:ok, battles} <- fetch_battles_for_comparison(battle_ids),
         {:ok, comparison} <- compare_battles(battles) do
      report = %{
        battles: Enum.map(battles, &summarize_battle/1),
        comparison: comparison,
        insights: generate_comparison_insights(comparison)
      }

      {:ok, report}
    end
  end

  # Private Functions

  defp generate_share_token(battle) do
    token =
      :crypto.strong_rand_bytes(@share_token_length)
      |> Base.url_encode64(padding: false)

    # Ensure uniqueness
    if token_exists?(token) do
      generate_share_token(battle)
    else
      {:ok, token}
    end
  end

  defp token_exists?(_token) do
    # Battle sharing functionality not yet implemented
    # Battle resource doesn't have share_token field
    false
  end

  defp update_battle_sharing_info(battle, share_token, options) do
    updates = %{
      share_token: share_token,
      sharing_enabled: true,
      share_created_at: DateTime.utc_now(),
      share_expires_at: calculate_expiry(options),
      share_options: options
    }

    BattleService.update_battle(battle.id, updates)
  end

  defp calculate_expiry(%{expires_in: hours}) when is_number(hours) do
    DateTimeUtils.add(DateTime.utc_now(), hours * 3600, :second)
  end

  # No expiry by default
  defp calculate_expiry(_), do: nil

  defp build_share_url(share_token) do
    "#{@share_url_base}#{share_token}"
  end

  defp generate_markdown_report(battle, analysis) do
    """
    # Battle Report - #{format_battle_date(battle.start_time)}

    ## Overview
    #{analysis.summary.headline}

    **Location:** System #{battle.system_id}
    **Duration:** #{battle.duration_minutes} minutes
    **Participants:** #{battle.participant_count}
    **ISK Destroyed:** #{format_isk_value(battle.total_value)}

    ## Key Statistics
    #{format_statistics_markdown(analysis.metrics)}

    ## Timeline
    #{format_timeline_markdown(analysis.timeline)}

    ## Top Performers
    #{format_participants_markdown(analysis.participants)}

    ## Fleet Compositions
    #{format_fleet_comp_markdown(analysis.fleet_composition)}

    ## Tactical Analysis
    #{format_tactical_markdown(analysis.tactical_patterns)}

    ---
    *Generated by EVE DMV - #{DateTime.utc_now() |> DateTime.to_string()}*
    """
  end

  defp generate_json_report(battle, analysis) do
    %{
      battle: %{
        id: battle.id,
        start_time: battle.start_time,
        end_time: battle.end_time,
        system_id: battle.system_id,
        participant_count: battle.participant_count,
        total_value: battle.total_value
      },
      analysis: analysis,
      metadata: %{
        generated_at: DateTime.utc_now(),
        version: "1.0"
      }
    }
  end

  defp generate_html_report(battle, analysis) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Battle Report - #{format_battle_date(battle.start_time)}</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: #1a1a1a; color: white; padding: 20px; border-radius: 8px; }
        .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin: 20px 0; }
        .stat-card { background: #f5f5f5; padding: 15px; border-radius: 8px; text-align: center; }
        .timeline { margin: 20px 0; }
        .event { border-left: 3px solid #007bff; padding-left: 15px; margin: 10px 0; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Battle Report</h1>
        <p>#{analysis.summary.headline}</p>
      </div>

      <div class="stats">
        #{format_stats_html(analysis.metrics)}
      </div>

      <div class="timeline">
        <h2>Battle Timeline</h2>
        #{format_timeline_html(analysis.timeline)}
      </div>

      <div class="participants">
        <h2>Top Participants</h2>
        #{format_participants_html(analysis.participants)}
      </div>
    </body>
    </html>
    """
  end

  defp generate_text_report(battle, analysis) do
    """
    BATTLE REPORT
    =============
    Date: #{format_battle_date(battle.start_time)}
    System: #{battle.system_id}
    Duration: #{battle.duration_minutes} minutes

    SUMMARY
    -------
    #{analysis.summary.headline}

    STATISTICS
    ----------
    Total Kills: #{battle.kill_count}
    Participants: #{battle.participant_count}
    ISK Destroyed: #{format_isk_value(battle.total_value)}

    TOP KILLERS
    -----------
    #{format_top_killers_text(analysis.participants)}

    TIMELINE
    --------
    #{format_timeline_text(analysis.timeline)}
    """
  end

  defp prepare_export_data(battle, options) do
    include_killmails = Map.get(options, :include_killmails, false)
    include_analysis = Map.get(options, :include_analysis, true)

    base_data = %{
      battle: serialize_battle(battle),
      metadata: %{
        exported_at: DateTime.utc_now(),
        export_version: "1.0"
      }
    }

    data_with_killmails =
      if include_killmails do
        Map.put(base_data, :killmails, get_battle_killmails(battle.id))
      else
        base_data
      end

    final_data =
      if include_analysis do
        case BattleAnalyzer.analyze_battle(battle.id) do
          {:ok, analysis} -> Map.put(data_with_killmails, :analysis, analysis)
          _ -> data_with_killmails
        end
      else
        data_with_killmails
      end

    {:ok, final_data}
  end

  defp serialize_battle(battle) do
    Map.take(battle, [
      :id,
      :system_id,
      :start_time,
      :end_time,
      :participant_count,
      :kill_count,
      :total_value,
      :ship_classes,
      :status
    ])
  end

  defp get_battle_killmails(_battle_id) do
    # Would fetch actual killmails from database
    []
  end

  defp export_to_csv(export_data) do
    # Convert to CSV format
    headers = ["Time", "Event", "Participants", "Value"]

    rows =
      export_data
      |> get_in([:analysis, :timeline, :events])
      |> Enum.map(fn event ->
        [
          DateTime.to_string(event.time),
          event.type,
          length(event.attackers),
          event.value
        ]
        |> Enum.join(",")
      end)

    [headers | rows] |> Enum.join("\n")
  end

  defp format_for_zkillboard(export_data) do
    # Format for zkillboard compatibility
    %{
      kills: export_data.killmails || [],
      battle_report: %{
        involved: export_data.battle.participant_count,
        start_time: export_data.battle.start_time,
        end_time: export_data.battle.end_time,
        solar_system_id: export_data.battle.system_id
      }
    }
  end

  defp build_battle_title(battle, _summary) do
    "Battle in #{battle.system_id} - #{format_battle_date(battle.start_time)}"
  end

  defp format_key_stats(stats) do
    Enum.map(stats, fn stat ->
      %{
        label: stat.label,
        value: format_stat_value(stat.value)
      }
    end)
  end

  defp format_stat_value(value) when is_number(value) do
    NumberFormatter.number_to_human(value)
  end

  defp format_stat_value(value), do: to_string(value)

  defp get_participant_breakdown(battle_id) do
    case ParticipantAnalyzer.get_participant_roles(battle_id) do
      {:ok, roles} ->
        Enum.map(roles, fn {role, participants} ->
          %{role: role, count: length(participants)}
        end)

      _ ->
        []
    end
  end

  defp format_isk_value(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk_value(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M ISK"
  end

  defp format_isk_value(value) do
    "#{round(value)} ISK"
  end

  defp format_duration(minutes) when minutes >= 60 do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)
    "#{hours}h #{mins}m"
  end

  defp format_duration(minutes) do
    "#{minutes}m"
  end

  defp generate_embed_code(battle_id, options) do
    width = Map.get(options, :width, 600)
    height = Map.get(options, :height, 400)

    """
    <iframe
      src="#{@share_url_base}embed/#{battle_id}"
      width="#{width}"
      height="#{height}"
      frameborder="0"
      allowfullscreen>
    </iframe>
    """
  end

  defp generate_preview_image_url(battle_id) do
    "#{@share_url_base}preview/#{battle_id}.png"
  end

  defp find_battle_by_token(_share_token) do
    # Battle sharing functionality not yet implemented
    # Battle resource doesn't have share_token field
    {:error, :battle_not_found}
  end

  defp verify_share_access(battle) do
    cond do
      not battle.sharing_enabled ->
        {:error, :sharing_disabled}

      battle.share_expires_at &&
          DateTimeUtils.compare(DateTime.utc_now(), battle.share_expires_at) == :gt ->
        {:error, :share_expired}

      true ->
        :ok
    end
  end

  defp fetch_battles_for_comparison(battle_ids) do
    battles =
      Enum.map(battle_ids, fn id ->
        case BattleService.get_battle(id) do
          {:ok, battle} -> battle
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if length(battles) == length(battle_ids) do
      {:ok, battles}
    else
      {:error, :some_battles_not_found}
    end
  end

  defp compare_battles(battles) do
    comparison = %{
      duration: compare_metric(battles, & &1.duration_minutes),
      participants: compare_metric(battles, & &1.participant_count),
      isk_destroyed: compare_metric(battles, & &1.total_value),
      kills: compare_metric(battles, & &1.kill_count),
      systems: Enum.map(battles, & &1.system_id) |> Enum.uniq()
    }

    {:ok, comparison}
  end

  defp compare_metric(battles, extractor) do
    values = Enum.map(battles, extractor)

    %{
      min: Enum.min(values),
      max: Enum.max(values),
      average: Enum.sum(values) / length(values),
      values: values
    }
  end

  defp summarize_battle(battle) do
    %{
      id: battle.id,
      start_time: battle.start_time,
      duration: battle.duration_minutes,
      participants: battle.participant_count,
      value: battle.total_value
    }
  end

  defp generate_comparison_insights(comparison) do
    initial_insights = []

    # Duration insights
    duration_variance = comparison.duration.max - comparison.duration.min

    insights_with_duration =
      if duration_variance > 30 do
        ["Significant duration variance (#{duration_variance} minutes)" | initial_insights]
      else
        initial_insights
      end

    # Scale insights
    participant_ratio = comparison.participants.max / max(comparison.participants.min, 1)

    final_insights =
      if participant_ratio > 3 do
        [
          "Large scale difference (#{Float.round(participant_ratio, 1)}x)"
          | insights_with_duration
        ]
      else
        insights_with_duration
      end

    final_insights
  end

  # Formatting helpers

  defp format_battle_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp format_statistics_markdown(metrics) do
    """
    - **ISK Efficiency:** #{metrics.efficiency.isk_efficiency}%
    - **Ships Destroyed:** #{metrics.destruction.ships_destroyed}
    - **Average Kill Value:** #{format_isk_value(metrics.destruction.total_isk / max(metrics.destruction.ships_destroyed, 1))}
    """
  end

  defp format_timeline_markdown(timeline) do
    timeline.events
    |> Enum.take(10)
    |> Enum.map_join("\n", fn event ->
      "- **#{format_time(event.time)}** - #{describe_event(event)}"
    end)
  end

  defp format_participants_markdown(participants) do
    participants.mvp_candidates
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {participant, rank} ->
      "#{rank}. **#{participant.character_name}** - #{participant.kills} kills, #{participant.deaths} deaths"
    end)
  end

  defp format_fleet_comp_markdown(fleet_comp) do
    fleet_comp.sides
    |> Enum.map_join("\n", fn {side, comp} ->
      """
      ### #{side}
      - Ships: #{comp.total_ships}
      - Unique Pilots: #{comp.unique_pilots}
      - Composition: #{format_ship_classes(comp.ship_classes)}
      """
    end)
  end

  defp format_tactical_markdown(patterns) do
    patterns
    |> Enum.map_join("\n", fn pattern ->
      "- **#{pattern.type}**: #{describe_pattern(pattern)}"
    end)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp describe_event(event) do
    "#{event.victim.character_name} lost #{event.victim.ship_name}"
  end

  defp format_ship_classes(ship_classes) do
    ship_classes
    |> Enum.map_join(", ", fn {class, data} ->
      "#{class} (#{data.count})"
    end)
  end

  defp describe_pattern(pattern) do
    case pattern.type do
      :focus_fire -> "Coordinated targeting detected"
      :capital_warfare -> "Capital ships engaged"
      :bombing_runs -> "Bombing runs executed"
      _ -> "Tactical pattern detected"
    end
  end

  defp format_stats_html(metrics) do
    """
    <div class="stat-card">
      <h3>Ships Destroyed</h3>
      <p>#{metrics.destruction.ships_destroyed}</p>
    </div>
    <div class="stat-card">
      <h3>ISK Destroyed</h3>
      <p>#{format_isk_value(metrics.destruction.total_isk)}</p>
    </div>
    <div class="stat-card">
      <h3>Efficiency</h3>
      <p>#{metrics.efficiency.isk_efficiency}%</p>
    </div>
    <div class="stat-card">
      <h3>Participants</h3>
      <p>#{metrics.participation.unique_pilots}</p>
    </div>
    """
  end

  defp format_timeline_html(timeline) do
    timeline.events
    |> Enum.take(10)
    |> Enum.map_join("\n", fn event ->
      """
      <div class="event">
        <strong>#{format_time(event.time)}</strong><br>
        #{describe_event(event)}
      </div>
      """
    end)
  end

  defp format_participants_html(participants) do
    """
    <table>
      <tr><th>Rank</th><th>Pilot</th><th>Kills</th><th>Deaths</th></tr>
      #{format_participant_rows(participants.mvp_candidates)}
    </table>
    """
  end

  defp format_participant_rows(participants) do
    participants
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {p, rank} ->
      "<tr><td>#{rank}</td><td>#{p.character_name}</td><td>#{p.kills}</td><td>#{p.deaths}</td></tr>"
    end)
  end

  defp format_top_killers_text(participants) do
    participants.mvp_candidates
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {p, rank} ->
      "#{rank}. #{p.character_name} (#{p.kills} kills)"
    end)
  end

  defp format_timeline_text(timeline) do
    timeline.events
    |> Enum.take(5)
    |> Enum.map_join("\n", fn event ->
      "#{format_time(event.time)} - #{describe_event(event)}"
    end)
  end
end
