defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ConstellationAnalyzer do
  @moduledoc """
  Analyzer for constellation-wide pattern analysis.
  """

  alias EveDmv.Api
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw

  require Ash.Query
  require Logger

  @doc """
  Analyze constellation-wide patterns.
  """
  def analyze_constellation_patterns(constellation_id, options \\ []) do
    Logger.debug("Analyzing constellation patterns for constellation #{constellation_id}")

    # Default 7 days in hours
    time_window = Keyword.get(options, :time_window, 24 * 7)
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window * 3600, :second)

    %{
      constellation_id: constellation_id,
      tactical_significance: assess_tactical_significance(constellation_id, cutoff_time),
      control_patterns: analyze_control_patterns(constellation_id, cutoff_time),
      strategic_value: assess_strategic_value(constellation_id),
      threat_assessment: assess_constellation_threats(constellation_id, cutoff_time)
    }
  end

  defp assess_tactical_significance(constellation_id, _cutoff_time) do
    # Analyze tactical significance based on system activity and positioning
    systems_query = Ash.Query.filter(SolarSystem, constellation_id == ^constellation_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the constellation (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Query recent killmail activity - simplified for now
        killmail_query =
    KillmailRaw
    Ash.Query.limit(100)
    Ash.Query.select([:killmail_id, :solar_system_id, :total_value])

        case Ash.read(killmail_query, domain: Api) do
          {:ok, killmails} ->
            # Calculate activity metrics
            total_kills = length(killmails)

            active_systems =
              killmails
              |> Enum.map(& &1.solar_system_id)
              |> Enum.uniq()
              |> length()

            total_isk_destroyed =
              Enum.reduce(killmails, Decimal.new(0), fn k, acc ->
                Decimal.add(acc, k.total_value || Decimal.new(0))
              end)

            # Assess strategic position based on system types
            wormhole_systems = Enum.count(systems, & &1.wormhole_class_id)
            lowsec_systems = Enum.count(systems, &(&1.security_class == "lowsec"))
            nullsec_systems = Enum.count(systems, &(&1.security_class == "nullsec"))

            strategic_position =
              cond do
                nullsec_systems > length(systems) * 0.5 -> :sovereignty
                wormhole_systems > 0 -> :wormhole_chain
                lowsec_systems > length(systems) * 0.5 -> :faction_warfare
                true -> :transit
              end

            tactical_value =
              cond do
                total_kills > 100 and active_systems > length(systems) * 0.7 -> :very_high
                total_kills > 50 or active_systems > length(systems) * 0.5 -> :high
                total_kills > 20 -> :moderate
                total_kills > 0 -> :low
                true -> :minimal
              end

            # Calculate defensive value based on system connectivity
            defensive_value = calculate_defensive_value(systems, active_systems, total_kills)

            %{
              tactical_value: tactical_value,
              strategic_position: strategic_position,
              defensive_value: defensive_value,
              active_systems: active_systems,
              total_systems: length(systems),
              recent_activity: total_kills,
              isk_destroyed: total_isk_destroyed
            }

          {:error, _} ->
            %{
              tactical_value: :unknown,
              strategic_position: :unknown,
              defensive_value: 0.0
            }
        end

      {:error, _} ->
        %{
          tactical_value: :unknown,
          strategic_position: :unknown,
          defensive_value: 0.0
        }
    end
  end

  defp analyze_control_patterns(constellation_id, _cutoff_time) do
    # Analyze which entities control the constellation
    systems_query = Ash.Query.filter(SolarSystem, constellation_id == ^constellation_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the constellation (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Get killmails with participants to analyze control - simplified for now
        control_query =
    KillmailRaw
    Ash.Query.limit(100)
    Ash.Query.load([:participants])
    Ash.Query.select([:killmail_id, :participants])

        case Ash.read(control_query, domain: Api) do
          {:ok, killmails} ->
            # Analyze entity presence
            entity_activity =
              killmails
              |> Enum.flat_map(&(&1.participants || []))
              |> Enum.filter(& &1.alliance_id)
              |> Enum.group_by(& &1.alliance_id)
              |> Enum.map(fn {alliance_id, participants} ->
                first = List.first(participants)

                {alliance_id,
                 %{
                   name: first.alliance_name,
                   activity_count: length(participants),
                   unique_characters:
                     participants
                     |> Enum.map(& &1.character_id)
                     |> Enum.uniq()
                     |> length()
                 }}
              end)
              |> Enum.sort_by(fn {_, data} -> data.activity_count end, :desc)
              |> Enum.take(5)

            # Determine control status
            {control_status, control_stability} = determine_control_status(entity_activity)

            controlling_entities =
              Enum.map(entity_activity, fn {id, data} ->
                %{
                  alliance_id: id,
                  alliance_name: data.name,
                  activity_share: data.activity_count,
                  unique_pilots: data.unique_characters
                }
              end)

            %{
              control_status: control_status,
              controlling_entities: controlling_entities,
              control_stability: control_stability
            }

          {:error, _} ->
            %{
              control_status: :unknown,
              controlling_entities: [],
              control_stability: 0.0
            }
        end

      {:error, _} ->
        %{
          control_status: :unknown,
          controlling_entities: [],
          control_stability: 0.0
        }
    end
  end

  defp assess_strategic_value(constellation_id) do
    # Assess strategic value based on constellation characteristics
    systems_query = Ash.Query.filter(SolarSystem, constellation_id == ^constellation_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Analyze system composition
        system_types = %{
          wormhole: Enum.count(systems, & &1.wormhole_class_id),
          nullsec: Enum.count(systems, &(&1.security_class == "nullsec")),
          lowsec: Enum.count(systems, &(&1.security_class == "lowsec")),
          highsec: Enum.count(systems, &(&1.security_class == "highsec"))
        }

        # Determine value factors
        value_factors = []

        value_factors =
          if system_types.wormhole > 0,
            do: [:wormhole_access | value_factors],
            else: value_factors

        value_factors =
          if system_types.nullsec > 0, do: [:sovereignty | value_factors], else: value_factors

        value_factors =
          if system_types.lowsec > 3, do: [:faction_warfare | value_factors], else: value_factors

        value_factors =
          if length(systems) > 10, do: [:large_territory | value_factors], else: value_factors

        # Calculate strategic importance
        strategic_importance =
          cond do
            system_types.nullsec > length(systems) * 0.7 -> 0.9
            system_types.wormhole > 0 -> 0.8
            system_types.lowsec > length(systems) * 0.5 -> 0.7
            length(systems) > 15 -> 0.6
            true -> 0.4
          end

        strategic_value =
          cond do
            strategic_importance > 0.8 -> :critical
            strategic_importance > 0.6 -> :high
            strategic_importance > 0.4 -> :moderate
            true -> :low
          end

        %{
          strategic_value: strategic_value,
          value_factors: value_factors,
          strategic_importance: strategic_importance,
          system_composition: system_types
        }

      {:error, _} ->
        %{
          strategic_value: :unknown,
          value_factors: [],
          strategic_importance: 0.0
        }
    end
  end

  defp assess_constellation_threats(constellation_id, _cutoff_time) do
    # Assess threats within the constellation
    systems_query = Ash.Query.filter(SolarSystem, constellation_id == ^constellation_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the constellation (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Query high-value losses as threat indicators - simplified for now
        threat_query =
    KillmailRaw
    Ash.Query.limit(50)
    Ash.Query.load([:participants])
    Ash.Query.sort(desc: :killmail_time)
    Ash.Query.limit(50)

        case Ash.read(threat_query, domain: Api) do
          {:ok, threat_kills} ->
            # Identify threat sources
            threat_sources =
    threat_kills
    |> Enum.flat_map(&(&1.participants || []))
    |> Enum.filter(&(!&1.is_victim && &1.corporation_id))
    |> Enum.group_by(&{&1.corporation_id, &1.corporation_name})
    |> Enum.map(fn {{corp_id, corp_name}, participants} ->
                %{
                  corporation_id: corp_id,
                  corporation_name: corp_name,
                  threat_actions: length(participants),
                  total_damage: Enum.reduce(participants, 0, &(&1.damage_done + &2))
                }
              end)
    |> Enum.sort_by(& &1.threat_actions, :desc)
    |> Enum.take(5)

            # Analyze threat trends
            recent_threats = Enum.take(threat_kills, 10)
            older_threats = Enum.slice(threat_kills, 10, 10)

            threat_trends =
              cond do
                length(recent_threats) > length(older_threats) * 1.5 -> :escalating
                length(recent_threats) < length(older_threats) * 0.5 -> :diminishing
                true -> :stable
              end

            threat_level =
              cond do
                length(threat_kills) > 40 -> :critical
                length(threat_kills) > 20 -> :high
                length(threat_kills) > 10 -> :moderate
                length(threat_kills) > 0 -> :low
                true -> :minimal
              end

            %{
              threat_level: threat_level,
              threat_sources: threat_sources,
              threat_trends: threat_trends,
              recent_losses: length(threat_kills)
            }

          {:error, _} ->
            %{
              threat_level: :unknown,
              threat_sources: [],
              threat_trends: :unknown
            }
        end

      {:error, _} ->
        %{
          threat_level: :unknown,
          threat_sources: [],
          threat_trends: :unknown
        }
    end
  end

  # Helper functions
  defp calculate_defensive_value(systems, active_systems, total_kills) do
    # Calculate defensive value based on multiple factors
    system_count = length(systems)
    activity_ratio = if system_count > 0, do: active_systems / system_count, else: 0

    # Lower activity might indicate better defensive position
    base_defensive_value =
      cond do
        total_kills < 10 and activity_ratio < 0.3 -> 0.9
        total_kills < 50 and activity_ratio < 0.5 -> 0.7
        total_kills < 100 -> 0.5
        true -> 0.3
      end

    # Adjust for system types (wormholes are harder to attack)
    wormhole_bonus = if Enum.any?(systems, & &1.wormhole_class_id), do: 0.1, else: 0

    min(base_defensive_value + wormhole_bonus, 1.0)
  end

  defp determine_control_status(entity_activity) do
    case entity_activity do
      [{_, top_entity} | rest] ->
        total_activity =
          Enum.reduce(entity_activity, 0, fn {_, e}, acc -> acc + e.activity_count end)

        top_percentage = top_entity.activity_count / total_activity

        cond do
          top_percentage > 0.7 -> {:dominated, top_percentage}
          top_percentage > 0.5 -> {:controlled, top_percentage * 0.8}
          length(rest) > 2 -> {:contested, 0.3}
          true -> {:disputed, 0.5}
        end

      [] ->
        {:unoccupied, 0.0}
    end
  end
end
