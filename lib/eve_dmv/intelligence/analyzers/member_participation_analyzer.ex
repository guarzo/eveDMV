defmodule EveDmv.Intelligence.Analyzers.MemberParticipationAnalyzer do
  @moduledoc """
  Member participation pattern analysis module.

  This module analyzes different types of member participation in EVE Online activities,
  including fleet operations, home defense, chain operations, and solo activities.
  It provides insights into participation patterns, rates, and metrics to help
  understand member engagement and contribution patterns.

  ## Participation Categories

  - **Home Defense**: Participation in defensive operations within identified home systems
  - **Chain Operations**: Participation in wormhole chain activities across multiple systems
  - **Fleet Operations**: Participation in organized fleet activities with multiple participants
  - **Solo Activities**: Individual activities without fleet participation

  ## Metrics Provided

  - Participation rates and counts for each activity type
  - Home system identification based on activity patterns
  - Fleet participation metrics including readiness scores
  - Activity categorization and trend analysis
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Utils.TimeUtils
  alias EveDmv.Intelligence.Analyzers.MemberActivityDataCollector

  @doc """
  Analyze participation patterns for a character across different activity types.

  Returns a map containing participation counts and rates for different activity types:
  - home_defense_count: Number of home defense participations
  - chain_operations_count: Number of chain operation participations
  - fleet_count: Number of fleet operation participations
  - solo_count: Number of solo activities
  - participation_rate: Overall participation rate (0.0 to 1.0)

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  `{:ok, participation_data}` where participation_data is a map with participation metrics
  """
  def analyze_participation_patterns(character_id, period_start, period_end) do
    Logger.debug("Analyzing participation patterns for character #{character_id}")

    # Validate inputs
    with :ok <- validate_character_id(character_id),
         :ok <- validate_date_range(period_start, period_end) do
      participation_data = %{
        home_defense_count:
          count_home_defense_participation(character_id, period_start, period_end),
        chain_operations_count: count_chain_operations(character_id, period_start, period_end),
        fleet_count: count_fleet_operations(character_id, period_start, period_end),
        solo_count: count_solo_activities(character_id, period_start, period_end),
        participation_rate: calculate_participation_rate(character_id, period_start, period_end)
      }

      {:ok, participation_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Count participation in home system defense activities.

  Home defense is identified by activity in systems where the character
  has the most defensive activity patterns.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  Integer count of home defense participations
  """
  def count_home_defense_participation(character_id, period_start, period_end) do
    Logger.debug("Counting home defense participation for character #{character_id}")

    case MemberActivityDataCollector.get_character_killmails(
           character_id,
           period_start,
           period_end
         ) do
      {:ok, killmails} ->
        # Identify home systems (systems with most defensive activity)
        home_systems = identify_character_home_systems(character_id, killmails)

        Enum.count(killmails, fn km ->
          # Participated as attacker in home system
          km.solar_system_id in home_systems and
            km.is_victim == false
        end)

      {:error, reason} ->
        Logger.warning("Failed to get killmails for home defense analysis: #{inspect(reason)}")
        0
    end
  end

  @doc """
  Count participation in wormhole chain operations.

  Chain operations are identified by activity across multiple systems
  within short time windows, indicating movement through wormhole chains.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  Integer count of chain operation participations
  """
  def count_chain_operations(character_id, period_start, period_end) do
    Logger.debug("Counting chain operations for character #{character_id}")

    case MemberActivityDataCollector.get_character_killmails(
           character_id,
           period_start,
           period_end
         ) do
      {:ok, killmails} ->
        # Chain operations typically involve multiple systems in short time windows
        killmails
        |> Stream.chunk_by(fn km ->
          TimeUtils.truncate_to_hour(km.killmail_time)
        end)
        |> Stream.map(fn hour_killmails ->
          # Multiple systems in same hour indicates chain activity
          unique_systems = hour_killmails |> Stream.map(& &1.solar_system_id) |> Enum.uniq()
          length(unique_systems) >= 2
        end)
        |> Enum.count(& &1)

      {:error, reason} ->
        Logger.warning(
          "Failed to get killmails for chain operations analysis: #{inspect(reason)}"
        )

        0
    end
  end

  @doc """
  Count participation in fleet operations (multi-participant activities).

  Fleet operations are identified by killmails with multiple attackers,
  indicating organized group activities.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  Integer count of fleet operation participations
  """
  def count_fleet_operations(character_id, period_start, period_end) do
    Logger.debug("Counting fleet operations for character #{character_id}")

    case MemberActivityDataCollector.get_character_killmails(
           character_id,
           period_start,
           period_end
         ) do
      {:ok, killmails} ->
        # Need to check participant count from enriched data
        fleet_kills =
          killmails
          |> Enum.map(fn km ->
            # Get full killmail data to check participant count
            case get_killmail_participants(km.killmail_id) do
              {:ok, participants} ->
                attacker_count = Enum.count(participants, &(&1.is_victim == false))
                {km, attacker_count}

              _ ->
                {km, 1}
            end
          end)
          |> Enum.count(fn {km, attacker_count} ->
            km.is_victim == false and attacker_count > 1
          end)

        fleet_kills

      {:error, reason} ->
        Logger.warning(
          "Failed to get killmails for fleet operations analysis: #{inspect(reason)}"
        )

        0
    end
  end

  @doc """
  Count solo activities (single-participant activities).

  Solo activities are identified by killmails where the character
  was the only attacker, indicating individual hunting or activities.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  Integer count of solo activities
  """
  def count_solo_activities(character_id, period_start, period_end) do
    Logger.debug("Counting solo activities for character #{character_id}")

    case MemberActivityDataCollector.get_character_killmails(
           character_id,
           period_start,
           period_end
         ) do
      {:ok, killmails} ->
        solo_kills =
          killmails
          |> Enum.map(fn km ->
            case get_killmail_participants(km.killmail_id) do
              {:ok, participants} ->
                attacker_count = Enum.count(participants, &(&1.is_victim == false))
                {km, attacker_count}

              _ ->
                {km, 1}
            end
          end)
          |> Enum.count(fn {km, attacker_count} ->
            km.is_victim == false and attacker_count == 1
          end)

        solo_kills

      {:error, reason} ->
        Logger.warning("Failed to get killmails for solo activities analysis: #{inspect(reason)}")
        0
    end
  end

  @doc """
  Calculate overall participation rate for a character.

  The participation rate is calculated as a normalized score based on
  the total activities relative to expected activity levels for the period.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `period_start`: Start of the analysis period
  - `period_end`: End of the analysis period

  ## Returns

  Float between 0.0 and 1.0 representing participation rate
  """
  def calculate_participation_rate(character_id, period_start, period_end) do
    Logger.debug("Calculating participation rate for character #{character_id}")

    # Calculate overall participation rate in corp activities
    home_defense = count_home_defense_participation(character_id, period_start, period_end)
    chain_ops = count_chain_operations(character_id, period_start, period_end)
    fleet_ops = count_fleet_operations(character_id, period_start, period_end)

    total_activities = home_defense + chain_ops + fleet_ops

    # Normalize to 0-1 scale (assume 10+ activities/month is 100%)
    days_in_period = TimeUtils.days_between(period_start, period_end)
    # Expect activity every 3 days
    expected_activities = max(1, days_in_period / 3)

    min(1.0, total_activities / expected_activities)
  end

  @doc """
  Identify character's home systems based on activity patterns.

  Home systems are identified by analyzing defensive and offensive activity
  patterns, with defensive activity weighted higher.

  ## Parameters

  - `character_id`: The character ID to analyze
  - `killmails`: List of killmails to analyze

  ## Returns

  List of system IDs representing the character's home systems (top 3)
  """
  def identify_character_home_systems(character_id, killmails) do
    Logger.debug("Identifying home systems for character #{character_id}")

    # Find systems where character is most active defensively
    killmails
    |> Enum.filter(&(&1.solar_system_id != nil))
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, system_killmails} ->
      defensive_activity = Enum.count(system_killmails, &(&1.is_victim == true))
      offensive_activity = Enum.count(system_killmails, &(&1.is_victim == false))

      # Weight defensive activity higher
      {system_id, defensive_activity + offensive_activity * 0.5}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    # Top 3 systems
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Calculate comprehensive fleet participation metrics.

  Analyzes fleet participation data to provide metrics on participation rates,
  high-participation members, leadership distribution, and fleet readiness.

  ## Parameters

  - `fleet_data`: List of member fleet participation data

  ## Returns

  Map containing:
  - `avg_participation_rate`: Average participation rate across all members
  - `high_participation_members`: List of members with >80% participation
  - `leadership_distribution`: Distribution of leadership roles
  - `fleet_readiness_score`: Overall fleet readiness score (0-100)
  """
  def calculate_fleet_participation_metrics(fleet_data) when is_list(fleet_data) do
    Logger.debug("Calculating fleet participation metrics for #{length(fleet_data)} members")

    if Enum.empty?(fleet_data) do
      %{
        avg_participation_rate: 0.0,
        high_participation_members: [],
        leadership_distribution: %{},
        fleet_readiness_score: 0
      }
    else
      participation_rates =
        Enum.map(fleet_data, fn member ->
          attended = Map.get(member, :fleet_ops_attended, 0)
          available = Map.get(member, :fleet_ops_available, 1)
          attended / max(1, available)
        end)

      durations = Enum.map(fleet_data, &Map.get(&1, :avg_fleet_duration, 0))
      leadership_roles = Enum.sum(Enum.map(fleet_data, &Map.get(&1, :leadership_roles, 0)))

      avg_participation =
        if length(participation_rates) > 0,
          do: Enum.sum(participation_rates) / length(participation_rates),
          else: 0.0

      _avg_duration =
        if length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0.0

      leadership_participation = leadership_roles / max(1, length(fleet_data))

      # Identify high participation members (>80% participation)
      high_participation_members =
        fleet_data
        |> Enum.zip(participation_rates)
        |> Enum.filter(fn {_member, rate} -> rate > 0.8 end)
        |> Enum.map(fn {member, _rate} -> member end)

      # Leadership distribution
      leadership_distribution = %{
        "fcs" => Enum.count(fleet_data, &(Map.get(&1, :role) == "fc")),
        "scouts" => Enum.count(fleet_data, &(Map.get(&1, :role) == "scout")),
        "logistics" => Enum.count(fleet_data, &(Map.get(&1, :role) == "logistics"))
      }

      # Fleet readiness score based on participation and leadership
      fleet_readiness_score = round(avg_participation * 100 + leadership_participation * 10)

      %{
        avg_participation_rate: Float.round(avg_participation, 3),
        high_participation_members: high_participation_members,
        leadership_distribution: leadership_distribution,
        fleet_readiness_score: min(100, fleet_readiness_score)
      }
    end
  end

  # Private helper functions

  defp validate_character_id(character_id) when is_integer(character_id) and character_id > 0,
    do: :ok

  defp validate_character_id(_), do: {:error, "Invalid character ID"}

  defp validate_date_range(%DateTime{} = start_date, %DateTime{} = end_date) do
    if DateTime.compare(start_date, end_date) == :lt do
      :ok
    else
      {:error, "Start date must be before end date"}
    end
  end

  defp validate_date_range(_, _), do: {:error, "Invalid date range"}

  defp get_killmail_participants(killmail_id) do
    query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id == ^killmail_id)

    case Ash.read(query, domain: Api) do
      {:ok, participants} -> {:ok, participants}
      {:error, reason} -> {:error, reason}
    end
  end
end
