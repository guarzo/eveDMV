defmodule EveDmv.Intelligence.CharacterAnalyzer do
  @moduledoc """
  Core character analysis coordination
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Eve.{EsiClient, ItemType, NameResolver}
  alias EveDmv.Intelligence.{CharacterStats, CharacterMetrics, CharacterFormatters}
  alias EveDmv.Killmails.{KillmailEnriched, Participant}
  require Ash.Query

  @analysis_period_days 90
  @min_activity_threshold 10

  @doc """
  Analyze a character and create/update their intelligence profile.
  """
  @spec analyze_character(integer()) :: {:ok, CharacterStats.t()} | {:error, term()}
  def analyze_character(character_id) do
    Logger.info("Analyzing character #{character_id}")

    with {:ok, basic_info} <- get_character_info(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id),
         {:ok, metrics} <- calculate_all_metrics(character_id, killmail_data),
         {:ok, character_stats} <- save_character_stats(basic_info, metrics) do
      {:ok, character_stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to analyze character #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters in batch.
  """
  def analyze_characters(character_ids) when is_list(character_ids) do
    Logger.info("Batch analyzing #{length(character_ids)} characters")

    results =
      character_ids
      |> Task.async_stream(&analyze_character_with_timeout/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, :timeout}
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = length(results) - successful

    Logger.info("Batch analysis complete: #{successful} successful, #{failed} failed")
    {:ok, results}
  end

  @doc """
  Process killmail data to extract character analysis information.
  """
  def process_killmail_data(raw_killmail_data) do
    # Convert raw killmail data into structured format for analysis
    participants = raw_killmail_data["participants"] || []

    processed = %{
      killmail_id: raw_killmail_data["killmail_id"],
      killmail_time: raw_killmail_data["killmail_time"],
      solar_system_id: raw_killmail_data["solar_system_id"],
      participants: participants,
      victim: find_victim_participant(participants),
      attackers: Enum.reject(participants, &(&1["is_victim"] == true)),
      zkb: raw_killmail_data["zkb"] || %{}
    }

    {:ok, processed}
  end

  # Private implementation functions

  defp analyze_character_with_timeout(character_id) do
    Task.async(fn -> analyze_character(character_id) end)
    |> Task.await(25_000)
  rescue
    error ->
      Logger.error("Error analyzing character #{character_id}: #{inspect(error)}")
      {:error, error}
  end

  defp get_character_info(character_id) do
    case EsiClient.get_character_info(character_id) do
      {:ok, character_data} ->
        # Get corporation and alliance info
        corp_info =
          case EsiClient.get_corporation_info(character_data["corporation_id"]) do
            {:ok, corp} -> corp
            {:error, _} -> %{"name" => "Unknown Corporation"}
          end

        alliance_info =
          case character_data["alliance_id"] do
            nil ->
              nil

            alliance_id ->
              case EsiClient.get_alliance_info(alliance_id) do
                {:ok, alliance} -> alliance
                {:error, _} -> %{"name" => "Unknown Alliance"}
              end
          end

        basic_info = %{
          character_id: character_id,
          character_name: character_data["name"],
          corporation_id: character_data["corporation_id"],
          corporation_name: corp_info["name"],
          alliance_id: character_data["alliance_id"],
          alliance_name: alliance_info && alliance_info["name"],
          security_status: character_data["security_status"],
          birthday: character_data["birthday"]
        }

        {:ok, basic_info}

      {:error, :not_found} ->
        # Try to get character info from killmail data as fallback
        get_character_info_from_killmails(character_id)

      {:error, reason} ->
        Logger.warning("Failed to get character info from ESI: #{inspect(reason)}")
        get_character_info_from_killmails(character_id)
    end
  end

  defp get_character_info_from_killmails(character_id) do
    # Get basic info from recent killmails as fallback
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.limit(1)
      |> Ash.Query.sort(updated_at: :desc)

    case Ash.read(participants_query, domain: Api) do
      {:ok, [participant | _]} ->
        basic_info = extract_basic_info(participant, character_id)
        {:ok, basic_info}

      {:ok, []} ->
        Logger.warning("No participant data found for character #{character_id}")
        {:error, :no_data}

      {:error, reason} ->
        Logger.error("Failed to query participant data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_basic_info(participant, character_id) do
    %{
      character_id: character_id,
      character_name: participant.character_name || "Unknown Character",
      corporation_id: participant.corporation_id,
      corporation_name: participant.corporation_name || "Unknown Corporation",
      alliance_id: participant.alliance_id,
      alliance_name: participant.alliance_name,
      security_status: nil,
      birthday: nil
    }
  end

  defp get_recent_killmails(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -@analysis_period_days, :day)

    # Get killmails where character was involved
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participants_query, domain: Api) do
      {:ok, participants} ->
        killmails = fetch_killmails_for_participants(participants)
        {:ok, build_killmails_with_participants(killmails, participants)}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch killmails for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp fetch_killmails_for_participants(participants) do
    killmail_ids = Enum.map(participants, & &1.killmail_id)

    KillmailEnriched
    |> Ash.Query.new()
    |> Ash.Query.filter(killmail_id in ^killmail_ids)
    |> Ash.read!(domain: Api)
  end

  defp build_killmails_with_participants(killmails, participants) do
    # Convert to format expected by metrics calculations
    Enum.map(killmails, fn killmail ->
      km_participants = Enum.filter(participants, &(&1.killmail_id == killmail.killmail_id))

      %{
        "killmail_id" => killmail.killmail_id,
        "killmail_time" => DateTime.to_iso8601(killmail.killmail_time),
        "solar_system_id" => killmail.solar_system_id,
        "participants" => Enum.map(km_participants, &participant_to_map/1),
        "victim" => find_victim_in_participants(km_participants),
        "attackers" => find_attackers_in_participants(km_participants),
        "zkb" => %{
          "totalValue" => Decimal.to_integer(killmail.total_value || Decimal.new(0))
        }
      }
    end)
  end

  defp calculate_all_metrics(character_id, killmail_data) do
    if length(killmail_data) < @min_activity_threshold do
      Logger.info(
        "Character #{character_id} has insufficient activity for analysis (#{length(killmail_data)} killmails)"
      )

      {:error, :insufficient_data}
    else
      metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)
      {:ok, metrics}
    end
  end

  defp save_character_stats(basic_info, metrics) do
    # Calculate completeness score based on available data
    completeness = calculate_completeness(metrics)

    # Build character stats resource
    stats_params = %{
      character_id: basic_info.character_id,
      character_name: basic_info.character_name,
      corporation_id: basic_info.corporation_id,
      corporation_name: basic_info.corporation_name,
      alliance_id: basic_info.alliance_id,
      alliance_name: basic_info.alliance_name,

      # Basic combat statistics
      kill_count: metrics.basic_stats.kills.count,
      loss_count: metrics.basic_stats.losses.count,
      solo_kill_count: metrics.basic_stats.kills.solo,
      total_kill_value: Decimal.new(metrics.basic_stats.kills.total_value),
      total_loss_value: Decimal.new(metrics.basic_stats.losses.total_value),
      dangerous_rating: round(metrics.danger_rating.score),

      # Derived metrics
      kd_ratio: metrics.basic_stats.kd_ratio,
      solo_ratio: metrics.basic_stats.solo_ratio,
      efficiency: metrics.basic_stats.efficiency,

      # Analysis metadata
      last_analyzed_at: DateTime.utc_now(),
      completeness_score: completeness,
      data_quality: assess_data_quality(metrics),

      # Store structured analysis data
      analysis_data: Jason.encode!(metrics)
    }

    case CharacterStats.create(stats_params, domain: Api) do
      {:ok, character_stats} ->
        Logger.info("Successfully saved character stats for #{basic_info.character_id}")
        {:ok, character_stats}

      {:error, reason} ->
        Logger.error("Failed to save character stats: #{inspect(reason)}")

        # Try to update existing record instead
        case CharacterStats.update_by_character_id(basic_info.character_id, stats_params,
               domain: Api
             ) do
          {:ok, character_stats} ->
            Logger.info("Successfully updated character stats for #{basic_info.character_id}")
            {:ok, character_stats}

          {:error, update_reason} ->
            Logger.error("Failed to update character stats: #{inspect(update_reason)}")
            {:error, update_reason}
        end
    end
  end

  # Helper functions

  defp find_victim_participant(participants) do
    Enum.find(participants, &(&1["is_victim"] == true))
  end

  defp participant_to_map(participant) do
    %{
      "character_id" => participant.character_id,
      "character_name" => participant.character_name,
      "corporation_id" => participant.corporation_id,
      "corporation_name" => participant.corporation_name,
      "alliance_id" => participant.alliance_id,
      "alliance_name" => participant.alliance_name,
      "ship_type_id" => participant.ship_type_id,
      "ship_name" => participant.ship_name,
      "damage_done" => participant.damage_done,
      "final_blow" => participant.final_blow,
      "is_victim" => participant.is_victim
    }
  end

  defp find_victim_in_participants(participants) do
    participant = Enum.find(participants, &(&1.is_victim == true))
    if participant, do: participant_to_map(participant), else: nil
  end

  defp find_attackers_in_participants(participants) do
    participants
    |> Enum.reject(&(&1.is_victim == true))
    |> Enum.map(&participant_to_map/1)
  end

  defp calculate_completeness(metrics) do
    # Calculate a completeness score based on available metrics
    total_possible = 10
    available = 0

    available = if metrics.basic_stats.kills.count > 0, do: available + 1, else: available
    available = if metrics.ship_usage.favorite_ships != [], do: available + 1, else: available

    available =
      if metrics.geographic_patterns.most_active_systems != [], do: available + 1, else: available

    available = if metrics.temporal_patterns.peak_hours != [], do: available + 1, else: available

    available =
      if metrics.frequent_associates.top_associates != [], do: available + 1, else: available

    available =
      if metrics.target_preferences.preferred_target_ships != [],
        do: available + 1,
        else: available

    available =
      if metrics.behavioral_patterns.risk_aversion != "Unknown",
        do: available + 1,
        else: available

    available =
      if metrics.weaknesses.vulnerable_to_ship_types != [], do: available + 1, else: available

    available = if metrics.danger_rating.score > 0, do: available + 1, else: available
    available = if metrics.success_rate > 0, do: available + 1, else: available

    (available / total_possible * 100) |> round()
  end

  defp assess_data_quality(metrics) do
    # Assess overall data quality
    total_activity = metrics.basic_stats.kills.count + metrics.basic_stats.losses.count

    cond do
      total_activity >= 100 -> "Excellent"
      total_activity >= 50 -> "Good"
      total_activity >= 25 -> "Fair"
      total_activity >= 10 -> "Limited"
      true -> "Poor"
    end
  end

  # Delegation to formatters
  defdelegate format_character_summary(analysis_results), to: CharacterFormatters
  defdelegate format_analysis_summary(character_stats), to: CharacterFormatters
end
