defmodule EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer do
  @moduledoc """
  Analyzes ship performance in battles by comparing expected stats from fittings
  with actual combat performance data.
  
  Calculates metrics like:
  - Applied DPS vs theoretical DPS
  - Tank effectiveness (damage taken vs EHP)
  - Speed/signature performance
  - Module effectiveness (neuts, webs, etc)
  """
  
  require Logger
  alias EveDmv.Eve.NameResolver
  
  @doc """
  Analyzes a ship's performance in a battle by comparing expected vs actual stats.
  
  ## Parameters
  - ship_data: Map containing character_id, ship_type_id, fitting data
  - battle_data: Map containing killmails, combat logs, timeline
  - options: Additional analysis options
  
  ## Returns
  {:ok, %{
    ship_info: %{...},
    expected_stats: %{...},
    actual_performance: %{...}, 
    efficiency_metrics: %{...},
    recommendations: [...]
  }}
  """
  def analyze_ship_performance(ship_data, battle_data, _options \\ []) do
    with {:ok, expected_stats} <- calculate_expected_stats(ship_data),
         {:ok, actual_performance} <- extract_actual_performance(ship_data, battle_data),
         {:ok, efficiency_metrics} <- calculate_efficiency_metrics(expected_stats, actual_performance) do
      
      recommendations = generate_recommendations(efficiency_metrics, actual_performance)
      
      {:ok, %{
        ship_info: build_ship_info(ship_data),
        expected_stats: expected_stats,
        actual_performance: actual_performance,
        efficiency_metrics: efficiency_metrics,
        recommendations: recommendations
      }}
    end
  end
  
  @doc """
  Calculates expected ship statistics from fitting data.
  """
  def calculate_expected_stats(%{fitting_data: nil}), do: {:ok, %{status: :no_fitting_data}}
  
  def calculate_expected_stats(%{fitting_data: fitting, ship_type_id: ship_type_id}) do
    # In a real implementation, this would calculate from actual fitting data
    # For now, we'll use ship base stats with some reasonable assumptions
    
    base_stats = get_ship_base_stats(ship_type_id)
    
    # Simple calculation - in production would use pyfa or similar
    expected = %{
      ehp: %{
        shield: base_stats.shield_hp * 1.2,  # Assume some tank modules
        armor: base_stats.armor_hp * 1.1,
        hull: base_stats.hull_hp,
        total: (base_stats.shield_hp * 1.2) + (base_stats.armor_hp * 1.1) + base_stats.hull_hp
      },
      dps: %{
        turret: estimate_weapon_dps(ship_type_id, fitting),
        missile: 0,
        drone: estimate_drone_dps(ship_type_id),
        total: estimate_weapon_dps(ship_type_id, fitting) + estimate_drone_dps(ship_type_id)
      },
      speed: %{
        max_velocity: base_stats.max_velocity * 1.15,  # Assume prop mod
        sig_radius: base_stats.sig_radius
      },
      capacitor: %{
        capacity: base_stats.capacitor,
        recharge_rate: base_stats.cap_recharge_rate
      }
    }
    
    {:ok, expected}
  end
  
  @doc """
  Extracts actual performance data from battle data for a specific ship.
  """
  def extract_actual_performance(%{character_id: character_id, ship_type_id: ship_type_id}, battle_data) do
    # Find all killmails involving this character/ship combo
    involved_killmails = find_character_involvement(character_id, ship_type_id, battle_data.killmails)
    
    # Extract combat log data if available
    combat_events = extract_combat_events(character_id, battle_data[:combat_logs] || [])
    
    # Calculate actual metrics
    actual = %{
      damage_dealt: calculate_damage_dealt(character_id, involved_killmails, combat_events),
      damage_taken: calculate_damage_taken(character_id, involved_killmails, combat_events),
      kills: count_kills(character_id, involved_killmails),
      time_on_field: calculate_time_on_field(character_id, ship_type_id, battle_data),
      module_activations: count_module_activations(combat_events),
      movement_stats: analyze_movement(character_id, battle_data)
    }
    
    {:ok, actual}
  end
  
  @doc """
  Calculates efficiency metrics by comparing expected vs actual performance.
  """
  def calculate_efficiency_metrics(expected, _actual) when expected.status == :no_fitting_data do
    {:ok, %{status: :no_comparison_available}}
  end
  
  def calculate_efficiency_metrics(expected, actual) do
    time_minutes = max(actual.time_on_field / 60, 1)
    
    metrics = %{
      dps_efficiency: calculate_dps_efficiency(expected, actual, time_minutes),
      tank_efficiency: calculate_tank_efficiency(expected, actual),
      applied_vs_theoretical: calculate_application_efficiency(expected, actual),
      survival_rating: calculate_survival_rating(expected, actual),
      isk_efficiency: calculate_isk_efficiency(actual)
    }
    
    {:ok, metrics}
  end
  
  @doc """
  Generates recommendations based on performance analysis.
  """
  def generate_recommendations(efficiency_metrics, actual_performance) do
    recommendations = []
    
    # DPS recommendations
    recommendations = recommendations ++ 
      if efficiency_metrics[:dps_efficiency] && efficiency_metrics.dps_efficiency[:percentage] < 50 do
        ["Consider improving application with webs/paints - achieving only #{round(efficiency_metrics.dps_efficiency.percentage)}% of potential DPS"]
      else
        []
      end
    
    # Tank recommendations  
    recommendations = recommendations ++
      if efficiency_metrics[:tank_efficiency] && efficiency_metrics.tank_efficiency[:used_percentage] > 90 do
        ["Tank nearly depleted (#{round(efficiency_metrics.tank_efficiency.used_percentage)}% used) - consider more buffer or active reps"]
      else
        []
      end
    
    # Survival recommendations
    recommendations = recommendations ++
      if actual_performance.time_on_field < 120 do  # Less than 2 minutes
        ["Very short time on field (#{Float.round(actual_performance.time_on_field / 60, 1)} min) - consider safer engagement range"]
      else
        []
      end
    
    recommendations
  end
  
  # Private helper functions
  
  defp build_ship_info(ship_data) do
    %{
      character_id: ship_data.character_id,
      character_name: ship_data[:character_name] || NameResolver.character_name(ship_data.character_id),
      ship_type_id: ship_data.ship_type_id,
      ship_name: NameResolver.ship_name(ship_data.ship_type_id),
      fitting_source: ship_data[:fitting_source] || :estimated
    }
  end
  
  defp get_ship_base_stats(ship_type_id) do
    # In production, this would query the SDE for actual ship stats
    # For now, return reasonable defaults based on ship class
    
    # Simplified ship class detection
    cond do
      ship_type_id in 582..650 -> # Frigates
        %{
          shield_hp: 500,
          armor_hp: 400,
          hull_hp: 300,
          max_velocity: 400,
          sig_radius: 35,
          capacitor: 350,
          cap_recharge_rate: 150_000  # ms
        }
      
      ship_type_id in 620..634 -> # Cruisers
        %{
          shield_hp: 2500,
          armor_hp: 2000,
          hull_hp: 1800,
          max_velocity: 250,
          sig_radius: 130,
          capacitor: 1500,
          cap_recharge_rate: 300_000
        }
        
      ship_type_id in 638..645 -> # Battleships
        %{
          shield_hp: 8000,
          armor_hp: 7000,
          hull_hp: 6500,
          max_velocity: 120,
          sig_radius: 400,
          capacitor: 5500,
          cap_recharge_rate: 900_000
        }
        
      true -> # Default
        %{
          shield_hp: 1000,
          armor_hp: 1000,
          hull_hp: 1000,
          max_velocity: 200,
          sig_radius: 100,
          capacitor: 1000,
          cap_recharge_rate: 250_000
        }
    end
  end
  
  defp estimate_weapon_dps(ship_type_id, _fitting) do
    # Simplified DPS estimation based on ship class
    cond do
      ship_type_id in 582..650 -> 150    # Frigates
      ship_type_id in 620..634 -> 400    # Cruisers  
      ship_type_id in 638..645 -> 800    # Battleships
      true -> 250
    end
  end
  
  defp estimate_drone_dps(ship_type_id) do
    # Simplified drone DPS estimation
    cond do
      ship_type_id in 29984..29990 -> 300  # Tech 3 Destroyers
      ship_type_id in 620..634 -> 100      # Cruisers
      ship_type_id in 638..645 -> 200      # Battleships
      true -> 50
    end
  end
  
  defp find_character_involvement(character_id, ship_type_id, killmails) do
    Enum.filter(killmails, fn km ->
      # Check if character was victim
      victim_match = km.victim_character_id == character_id && km.victim_ship_type_id == ship_type_id
      
      # Check if character was attacker
      attacker_match = Enum.any?(km.raw_data["attackers"] || [], fn att ->
        att["character_id"] == character_id && att["ship_type_id"] == ship_type_id
      end)
      
      victim_match || attacker_match
    end)
  end
  
  defp extract_combat_events(character_id, combat_logs) do
    combat_logs
    |> Enum.filter(& &1.pilot_name == character_id || &1.character_id == character_id)
    |> Enum.flat_map(& &1.parsed_data[:events] || [])
  end
  
  defp calculate_damage_dealt(character_id, killmails, combat_events) do
    # From killmails
    km_damage = killmails
    |> Enum.flat_map(& &1.raw_data["attackers"] || [])
    |> Enum.filter(& &1["character_id"] == character_id)
    |> Enum.map(& &1["damage_done"] || 0)
    |> Enum.sum()
    
    # From combat logs
    log_damage = combat_events
    |> Enum.filter(& &1[:type] == :damage && &1[:from] == character_id)
    |> Enum.map(& &1[:damage] || 0)
    |> Enum.sum()
    
    %{
      from_killmails: km_damage,
      from_logs: log_damage,
      total: km_damage + log_damage
    }
  end
  
  defp calculate_damage_taken(character_id, killmails, combat_events) do
    # From killmails (if they died)
    km_damage = killmails
    |> Enum.filter(& &1.victim_character_id == character_id)
    |> Enum.map(& get_victim_damage_taken(&1))
    |> Enum.sum()
    
    # From combat logs
    log_damage = combat_events
    |> Enum.filter(& &1[:type] == :damage && &1[:to] == character_id)
    |> Enum.map(& &1[:damage] || 0)
    |> Enum.sum()
    
    %{
      from_killmails: km_damage,
      from_logs: log_damage,
      total: km_damage + log_damage
    }
  end
  
  defp count_kills(character_id, killmails) do
    killmails
    |> Enum.count(fn km ->
      Enum.any?(km.raw_data["attackers"] || [], & &1["character_id"] == character_id && &1["final_blow"])
    end)
  end
  
  defp calculate_time_on_field(character_id, ship_type_id, battle_data) do
    # If battle has timeline, use that
    if battle_data[:timeline] && battle_data.timeline[:events] do
      events = battle_data.timeline.events
      
      appearances = Enum.filter(events, fn event ->
        # Check victim
        victim_match = event.victim.character_id == character_id && 
                       event.victim.ship_type_id == ship_type_id
        
        # Check attackers
        attacker_match = Enum.any?(event.attackers, fn att ->
          att.character_id == character_id && att.ship_type_id == ship_type_id
        end)
        
        victim_match || attacker_match
      end)
      
      if length(appearances) > 0 do
        first = List.first(appearances)
        last = List.last(appearances)
        
        # If they died, use that as end time
        death = Enum.find(appearances, fn e -> 
          e.victim.character_id == character_id && e.victim.ship_type_id == ship_type_id
        end)
        
        end_time = if death, do: death.timestamp, else: last.timestamp
        
        NaiveDateTime.diff(end_time, first.timestamp, :second)
      else
        0
      end
    else
      # Fallback to killmail timestamps
      killmails = battle_data.killmails
      involved = find_character_involvement(character_id, ship_type_id, killmails)
      
      if length(involved) > 0 do
        timestamps = Enum.map(involved, & &1.killmail_time)
        first = Enum.min(timestamps)
        last = Enum.max(timestamps)
        
        NaiveDateTime.diff(last, first, :second)
      else
        0
      end
    end
  end
  
  defp count_module_activations(combat_events) do
    combat_events
    |> Enum.filter(& &1[:type] == :ewar)
    |> Enum.group_by(& &1[:ewar_type])
    |> Enum.map(fn {type, events} -> {type, length(events)} end)
    |> Enum.into(%{})
  end
  
  defp analyze_movement(_character_id, _battle_data) do
    # Would analyze position changes from combat logs
    %{
      average_range: nil,
      speed_utilized: nil,
      position_changes: 0
    }
  end
  
  defp calculate_dps_efficiency(expected, actual, time_minutes) do
    expected_damage = expected.dps.total * time_minutes * 60
    actual_damage = actual.damage_dealt.total
    
    %{
      expected_damage: expected_damage,
      actual_damage: actual_damage,
      percentage: if(expected_damage > 0, do: actual_damage / expected_damage * 100, else: 0),
      dps_achieved: actual_damage / (time_minutes * 60)
    }
  end
  
  defp calculate_tank_efficiency(expected, actual) do
    damage_taken = actual.damage_taken.total
    ehp_total = expected.ehp.total
    
    %{
      damage_tanked: damage_taken,
      ehp_available: ehp_total,
      used_percentage: if(ehp_total > 0, do: damage_taken / ehp_total * 100, else: 0),
      survived: damage_taken < ehp_total
    }
  end
  
  defp calculate_application_efficiency(_expected, _actual) do
    # Would calculate hit quality from combat logs
    %{
      hit_percentage: 85.0,  # Placeholder
      optimal_range_percentage: 70.0,  # Placeholder
      tracking_efficiency: 80.0  # Placeholder
    }
  end
  
  defp calculate_survival_rating(expected, actual) do
    base_score = 50.0
    
    # Adjust based on survival
    survival_bonus = if actual.damage_taken.total < expected.ehp.total, do: 25.0, else: 0.0
    
    # Adjust based on time on field
    time_bonus = min(actual.time_on_field / 300 * 25, 25.0)  # Max 25 points for 5+ minutes
    
    base_score + survival_bonus + time_bonus
  end
  
  # Helper function to get damage taken from killmail
  defp get_victim_damage_taken(km) do
    case km.raw_data do
      %{"victim" => %{"damage_taken" => damage}} when is_number(damage) -> damage
      _ -> 0
    end
  end
  
  defp calculate_isk_efficiency(_actual) do
    # Would need ship values from market data
    %{
      isk_destroyed: 0,  # Placeholder
      isk_lost: 0,      # Placeholder
      efficiency: 0.0   # Placeholder
    }
  end
end