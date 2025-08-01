defmodule EveDmv.Contexts.BattleAnalysis.Services.BattleSharingService do
  @moduledoc """
  Service for sharing battle reports and analysis.

  Handles:
  - Generating shareable battle reports
  - Creating battle permalinks
  - Exporting battle data in various formats
  - Managing battle visibility and access
  """

  import Ash.Expr

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleAnalyzer
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.BattleAnalysis.Services.BattleService
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

  defp token_exists?(token) do
    # Check if token already exists in database
    Battle
    |> Ash.Query.filter(expr(share_token == ^token))
    |> Ash.read!()
    |> Enum.any?()
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
    DateTime.add(DateTime.utc_now(), hours * 3600, :second)
  end

  # No expiry by default
  defp calculate_expiry(_), do: nil

  defp build_share_url(share_token) do
    "#{@share_url_base}#{share_token}"
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

    final_data =
      base_data
      |> maybe_add_killmails(battle.id, include_killmails)
      |> maybe_add_analysis(battle.id, include_analysis)

    {:ok, final_data}
  end

  defp maybe_add_killmails(data, battle_id, true) do
    Map.put(data, :killmails, get_battle_killmails(battle_id))
  end

  defp maybe_add_killmails(data, _battle_id, false), do: data

  defp maybe_add_analysis(data, battle_id, true) do
    case BattleAnalyzer.analyze_battle(battle_id) do
      {:ok, analysis} -> Map.put(data, :analysis, analysis)
      _ -> data
    end
  end

  defp maybe_add_analysis(data, _battle_id, false), do: data

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

  defp get_battle_killmails(battle_id) do
    # Fetch actual killmails associated with the battle
    case Battle
         |> Ash.Query.filter(expr(id == ^battle_id))
         |> Ash.Query.load(:killmails)
         |> Ash.read_one() do
      {:ok, battle} when not is_nil(battle) ->
        battle.killmails

      _ ->
        Logger.warning("No killmails found for battle #{battle_id}")
        []
    end
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
    # Retrieve and analyze participants from battle killmails
    case BattleService.get_battle(battle_id) do
      {:ok, battle} ->
        analyze_battle_participants(battle)

      {:error, _} ->
        []
    end
  end

  defp analyze_battle_participants(battle) do
    # Get killmails for this battle and analyze participant breakdown
    killmails = get_battle_killmails(battle.id)

    if Enum.empty?(killmails) do
      []
    else
      # Extract all participants from killmails
      participants = extract_battle_participants(killmails)

      # Group by affiliation and analyze
      participants
      |> group_participants_by_affiliation()
      |> Enum.map(&format_participant_group/1)
      |> Enum.sort_by(fn group -> group.participant_count end, :desc)
    end
  end

  defp extract_battle_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Extract victim
      victim = %{
        character_id: km.victim["character_id"],
        character_name: km.victim["character_name"],
        corporation_id: km.victim["corporation_id"],
        corporation_name: km.victim["corporation_name"],
        alliance_id: km.victim["alliance_id"],
        alliance_name: km.victim["alliance_name"],
        ship_type_id: km.victim["ship_type_id"],
        role: :victim
      }

      # Extract attackers
      attackers =
        (km.attackers || [])
        |> Enum.map(fn attacker ->
          %{
            character_id: attacker["character_id"],
            character_name: attacker["character_name"],
            corporation_id: attacker["corporation_id"],
            corporation_name: attacker["corporation_name"],
            alliance_id: attacker["alliance_id"],
            alliance_name: attacker["alliance_name"],
            ship_type_id: attacker["ship_type_id"],
            role: :attacker
          }
        end)
        |> Enum.reject(fn attacker -> is_nil(attacker.character_id) end)

      [victim | attackers]
    end)
    |> Enum.reject(fn participant -> is_nil(participant.character_id) end)
    |> Enum.uniq_by(fn participant -> participant.character_id end)
  end

  defp group_participants_by_affiliation(participants) do
    # Group by alliance first, then by corporation for non-alliance members
    participants
    |> Enum.group_by(fn participant ->
      if participant.alliance_id && participant.alliance_id != 0 do
        {:alliance, participant.alliance_id, participant.alliance_name}
      else
        {:corporation, participant.corporation_id, participant.corporation_name}
      end
    end)
  end

  defp format_participant_group({affiliation_key, group_participants}) do
    {type, id, name} = affiliation_key

    # Analyze ships used by this group
    ship_breakdown =
      group_participants
      |> Enum.map(fn p -> p.ship_type_id end)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()
      |> Enum.map(fn {ship_type_id, count} ->
        ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
        %{ship_type_id: ship_type_id, ship_class: ship_class, count: count}
      end)
      |> group_by_ship_class()

    %{
      affiliation_type: type,
      affiliation_id: id,
      affiliation_name: name || "Unknown",
      participant_count: length(group_participants),
      ship_classes: ship_breakdown,
      # Sample of pilots
      pilots: Enum.take(group_participants, 10)
    }
  end

  defp group_by_ship_class(ship_breakdown) do
    ship_breakdown
    |> Enum.group_by(fn ship -> ship.ship_class end)
    |> Enum.map(fn {class, ships} ->
      total_count = Enum.reduce(ships, 0, fn ship, acc -> acc + ship.count end)
      {class, total_count}
    end)
    |> Map.new()
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

  defp find_battle_by_token(share_token) do
    case Battle
         |> Ash.Query.filter(expr(share_token == ^share_token))
         |> Ash.read_one() do
      {:ok, battle} when not is_nil(battle) -> {:ok, battle}
      _ -> {:error, :battle_not_found}
    end
  end

  defp verify_share_access(battle) do
    cond do
      not battle.sharing_enabled ->
        {:error, :sharing_disabled}

      battle.share_expires_at &&
          DateTime.compare(DateTime.utc_now(), battle.share_expires_at) == :gt ->
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
    base_insights = []

    # Duration insights
    duration_variance = comparison.duration.max - comparison.duration.min
    participant_ratio = comparison.participants.max / max(comparison.participants.min, 1)

    base_insights
    |> maybe_add_duration_insight(duration_variance)
    |> maybe_add_scale_insight(participant_ratio)
  end

  defp maybe_add_duration_insight(insights, duration_variance) when duration_variance > 30 do
    ["Significant duration variance (#{duration_variance} minutes)" | insights]
  end

  defp maybe_add_duration_insight(insights, _duration_variance), do: insights

  defp maybe_add_scale_insight(insights, participant_ratio) when participant_ratio > 3 do
    ["Large scale difference (#{Float.round(participant_ratio, 1)}x)" | insights]
  end

  defp maybe_add_scale_insight(insights, _participant_ratio), do: insights

  # Formatting helpers

  defp format_battle_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
