defmodule EveDmv.Contexts.Combat.Services.BattleSharingService do
  @compile {:nowarn_unused_function}
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

  # Removed unused function generate_battle_report/2

  # Removed unused function export_battle_data/2

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
    else
      error -> error
    end
  end

  @doc """
  Get battle by share token.
  """
  def get_shared_battle(_share_token) do
    # Battle sharing functionality not yet implemented
    {:error, :battle_not_found}
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
    end
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

  # Helper functions

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

  defp generate_preview_image_url(battle_id) do
    "#{@share_url_base}preview/#{battle_id}.png"
  end

  defp format_battle_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  # Formatting helpers
end
