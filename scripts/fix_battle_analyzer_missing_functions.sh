#!/bin/bash
echo "=== Fixing Missing Functions in Combat BattleAnalyzer ==="

# Extract the missing functions from battle_analysis version and append to combat version
cat >> /workspace/lib/eve_dmv/contexts/combat/core/battle_analyzer.ex << 'EOF'

  # Missing helper functions copied from battle_analysis version
  
  defp count_solo_kills(killmails) do
    Enum.count(killmails, fn km ->
      length(km.attackers || []) == 1
    end)
  end

  defp calculate_average_on_kill(killmails) do
    total_attackers =
      Enum.reduce(killmails, 0, fn km, acc ->
        acc + length(km.attackers || [])
      end)

    if length(killmails) > 0, do: total_attackers / length(killmails), else: 0
  end

  defp calculate_kd_ratio(participants) do
    # Calculate overall kill/death ratio for the battle
    case participants do
      %{all_participants: all_chars} when is_list(all_chars) ->
        total_participants = length(all_chars)

        if total_participants > 0 do
          # K/D ratio approximation: total kills / unique participants
          # This gives average kills per participant
          total_participants / max(total_participants, 1)
        else
          1.0
        end

      _ ->
        1.0
    end
  end

  defp generate_headline(analysis) do
    scale = analysis.summary.scale
    type = analysis.summary.type
    location = analysis.summary.location.system_id

    "#{scale} #{type} in system #{location}"
  end

  defp extract_key_stats(analysis) do
    [
      %{label: "Duration", value: "#{analysis.summary.time_span.duration_minutes} minutes"},
      %{label: "Participants", value: analysis.metrics.participation.unique_pilots},
      %{label: "ISK Destroyed", value: format_isk(analysis.metrics.destruction.total_isk)},
      %{label: "Ships Lost", value: analysis.metrics.destruction.ships_destroyed}
    ]
  end

  defp determine_winner(analysis) do
    # Determine winner based on ISK efficiency and field control
    case analysis do
      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff > 60 ->
        :decisive_victory

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff > 40 ->
        :tactical_victory

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff < 40 ->
        :tactical_defeat

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff < 20 ->
        :decisive_defeat

      _ ->
        :undetermined
    end
  end

  defp find_mvp(analysis) do
    # Find MVP based on damage dealt and tactical contribution
    case analysis do
      %{performance_metrics: %{individual_performance: pilots}} when is_list(pilots) ->
        pilots
        |> Enum.max_by(
          fn pilot ->
            damage = Map.get(pilot, :damage_dealt, 0)
            kills = Map.get(pilot, :final_blows, 0)
            # Composite score
            damage * 0.7 + kills * 1000 * 0.3
          end,
          fn -> nil end
        )
        |> case do
          nil ->
            nil

          pilot ->
            %{
              character_id: Map.get(pilot, :character_id),
              character_name:
                EveDmv.Eve.NameResolver.character_name(Map.get(pilot, :character_id, 0)),
              damage_dealt: Map.get(pilot, :damage_dealt, 0),
              final_blows: Map.get(pilot, :final_blows, 0)
            }
        end

      _ ->
        nil
    end
  end

  defp identify_turning_point(analysis) do
    # Identify turning point based on timeline analysis
    case analysis do
      %{timeline: %{events: events}} when is_list(events) and length(events) > 5 ->
        # Find the event with the biggest shift in momentum
        # Look for high-value kills or multiple simultaneous kills
        events
        |> Enum.with_index()
        |> Enum.max_by(
          fn {event, _idx} ->
            isk_value = get_in(event, [:victim, :zkb, "totalValue"]) || 0
            # Weight by both ISK value and tactical importance
            ship_type_id = get_in(event, [:victim, "ship_type_id"])

            tactical_weight =
              case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id || 0) do
                :capital -> 3.0
                # Logistics ships are tactically critical
                :logistics -> 2.5
                :supercapital -> 4.0
                _ -> 1.0
              end

            isk_value * tactical_weight
          end,
          fn -> nil end
        )
        |> case do
          nil ->
            nil

          {event, idx} ->
            %{
              event_index: idx,
              timestamp: event.timestamp,
              description:
                "High-value kill: #{get_in(event, [:victim, "ship_name"]) || "Unknown ship"}",
              isk_value: get_in(event, [:victim, :zkb, "totalValue"]) || 0
            }
        end

      _ ->
        nil
    end
  end

  defp find_notable_kills(analysis) do
    # Find notable kills based on ISK value and ship importance
    case analysis do
      %{timeline: %{events: events}} when is_list(events) ->
        events
        |> Enum.filter(fn event ->
          isk_value = get_in(event, [:victim, :zkb, "totalValue"]) || 0
          ship_type_id = get_in(event, [:victim, "ship_type_id"]) || 0
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

          # Notable if high ISK value or important ship class
          isk_value > 100_000_000 or ship_class in [:capital, :supercapital]
        end)
        |> Enum.sort_by(&(get_in(&1, [:victim, :zkb, "totalValue"]) || 0), :desc)
        |> Enum.take(5)
        |> Enum.map(fn event ->
          %{
            killmail_id: event.killmail_id,
            victim_name: get_in(event, [:victim, "character_name"]) || "Unknown",
            ship_name: get_in(event, [:victim, "ship_name"]) || "Unknown Ship",
            isk_value: get_in(event, [:victim, :zkb, "totalValue"]) || 0,
            timestamp: event.timestamp
          }
        end)

      _ ->
        []
    end
  end
EOF

echo "Missing functions added to combat BattleAnalyzer!"