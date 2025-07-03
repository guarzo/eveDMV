defmodule EveDmv.TestMocks do
  @moduledoc """
  Mock implementations for external services and complex dependencies.
  """

  # Mock ESI Client
  defmodule MockEsiClient do
    @moduledoc """
    Mock implementation of ESI client for testing.
    """
    def get_character(character_id) do
      {:ok,
       %{
         character_id: character_id,
         name: "Test Character #{character_id}",
         corporation_id: 98_000_001,
         alliance_id: 99_000_001,
         birthday: ~D[2010-01-01],
         security_status: 0.0
       }}
    end

    def get_corporation(corp_id) do
      {:ok,
       %{
         corporation_id: corp_id,
         name: "Test Corporation #{corp_id}",
         ticker: "TEST",
         member_count: 50
       }}
    end

    def get_alliance(alliance_id) do
      {:ok,
       %{
         alliance_id: alliance_id,
         name: "Test Alliance #{alliance_id}",
         ticker: "TESTA"
       }}
    end
  end

  # Mock Wanderer Client
  defmodule MockWandererClient do
    @moduledoc """
    Mock implementation of Wanderer client for testing.
    """
    def get_chain_topology(_map_id) do
      {:ok,
       %{
         systems: [
           %{system_id: 31_000_001, system_name: "J100001", security_status: -0.99}
         ],
         connections: [],
         last_updated: DateTime.utc_now()
       }}
    end

    def get_system_inhabitants(_map_id) do
      {:ok,
       [
         %{
           character_id: 123_456,
           character_name: "Test Pilot",
           system_id: 31_000_001,
           ship_type_id: 11_999
         }
       ]}
    end

    def monitor_map(_map_id) do
      :ok
    end

    def stop_monitoring(_map_id) do
      :ok
    end
  end

  # Mock data generators with configurable options
  def mock_killmail(character_id \\ 123_456_789, opts \\ %{}) do
    defaults = %{
      corporation_id: 98_000_001,
      corporation_name: "Test Corp",
      alliance_id: 99_000_001,
      alliance_name: "Test Alliance",
      solar_system_id: nil,
      ship_type_id: nil,
      is_victim: nil,
      total_value: nil
    }
    
    config = Map.merge(defaults, opts)
    
    %{
      killmail_id: :rand.uniform(999_999_999),
      killmail_time: DateTime.add(DateTime.utc_now(), -:rand.uniform(86_400), :second),
      solar_system_id: config.solar_system_id || Enum.random([30_002_187, 30_000_142, 31_000_001]),
      is_victim: config.is_victim || Enum.random([true, false]),
      ship_type_id: config.ship_type_id || Enum.random([11_999, 12_003, 670]),
      ship_name: Enum.random(["Rifter", "Crucifier", "Capsule"]),
      character_id: character_id,
      character_name: "Test Pilot #{character_id}",
      corporation_id: config.corporation_id,
      corporation_name: config.corporation_name,
      alliance_id: config.alliance_id,
      alliance_name: config.alliance_name,
      attacker_count: :rand.uniform(10),
      total_value: config.total_value || :rand.uniform(100_000_000)
    }
  end

  def mock_killmails(character_id, count \\ 10, opts \\ %{}) do
    Enum.map(1..count, fn _ -> mock_killmail(character_id, opts) end)
  end

  def mock_member_activity(character_id \\ 123_456, opts \\ %{}) do
    defaults = %{
      character_name: "Member #{character_id}",
      corporation_id: 98_000_001,
      corporation_name: "Test Corp",
      alliance_id: 99_000_001,
      alliance_name: "Test Alliance",
      timezone: nil,
      activity_score: nil
    }
    
    config = Map.merge(defaults, opts)
    
    %{
      character_id: character_id,
      character_name: config.character_name,
      last_seen: DateTime.add(DateTime.utc_now(), -:rand.uniform(86_400), :second),
      killmail_count: :rand.uniform(100),
      fleet_participation: :rand.uniform() * 0.8 + 0.1,
      communication_activity: :rand.uniform(50),
      days_since_join: :rand.uniform(365),
      timezone: config.timezone || Enum.random(["UTC", "US/Eastern", "Australia/Sydney"]),
      active_hours: Enum.take_random(0..23, :rand.uniform(8) + 4),
      activity_score: config.activity_score || :rand.uniform(100)
    }
  end

  def mock_employment_history(character_id \\ 123_456, opts \\ %{}) do
    defaults = %{
      current_corp_id: 98_000_001,
      current_corp_name: "Current Corp",
      previous_corp_id: 98_000_002,
      previous_corp_name: "Previous Corp"
    }
    
    config = Map.merge(defaults, opts)
    
    [
      %{
        corporation_id: config.current_corp_id,
        corporation_name: config.current_corp_name,
        start_date: DateTime.add(DateTime.utc_now(), -365, :day),
        end_date: nil,
        is_deleted: false
      },
      %{
        corporation_id: config.previous_corp_id,
        corporation_name: config.previous_corp_name,
        start_date: DateTime.add(DateTime.utc_now(), -730, :day),
        end_date: DateTime.add(DateTime.utc_now(), -365, :day),
        is_deleted: false
      }
    ]
  end

  def mock_ship_usage_data do
    %{
      most_used_ships: [
        %{ship_name: "Rifter", usage_count: 25, success_rate: 0.7},
        %{ship_name: "Crucifier", usage_count: 15, success_rate: 0.8},
        %{ship_name: "Interceptor", usage_count: 10, success_rate: 0.6}
      ],
      ship_success_rates: %{
        "Rifter" => 0.7,
        "Crucifier" => 0.8,
        "Interceptor" => 0.6
      },
      preferred_ship_categories: %{
        "frigate" => 0.6,
        "interceptor" => 0.3,
        "other" => 0.1
      },
      total_unique_ships: 15
    }
  end

  def mock_character_analysis(character_id \\ 123_456_789) do
    %{
      character_id: character_id,
      character_name: "Test Pilot #{character_id}",
      corporation_id: 98_000_001,
      corporation_name: "Test Corp",
      alliance_id: 99_000_001,
      alliance_name: "Test Alliance",
      total_kills: 50,
      total_losses: 12,
      solo_kills: 25,
      isk_destroyed: 5_000_000_000.0,
      isk_lost: 1_000_000_000.0,
      isk_efficiency: 83.3,
      kill_death_ratio: 4.17,
      dangerous_rating: 3,
      data_completeness: 85,
      ship_usage: mock_ship_usage_data(),
      frequent_associates: %{
        "456789" => %{
          "name" => "Associate Pilot",
          "shared_kills" => 15,
          "corp_name" => "Same Corp",
          "is_logistics" => false
        }
      },
      active_systems: %{
        30_002_187 => 25,
        31_000_001 => 15,
        30_000_142 => 10
      },
      target_profile: %{
        preferred_target_types: %{"frigate" => 0.4, "cruiser" => 0.3},
        avg_target_value: 25_000_000,
        target_size_preference: %{"small" => 0.6, "medium" => 0.4}
      },
      identified_weaknesses: %{
        "behavioral" => ["predictable_schedule"],
        "technical" => [],
        "loss_patterns" => ["overconfident"]
      },
      prime_timezone: "USTZ",
      home_system_id: 30_002_187,
      home_system_name: "Rens",
      avg_gang_size: 3.2,
      aggression_index: 0.75,
      last_calculated_at: DateTime.utc_now()
    }
  end

  def mock_vetting_analysis(character_id \\ 123_456_789) do
    %{
      character_id: character_id,
      character_name: "Vetted Pilot #{character_id}",
      analyst_character_id: 987_654_321,
      j_space_experience: %{
        total_j_kills: 25,
        total_j_losses: 5,
        j_space_time_percent: 60.0,
        wormhole_systems_visited: [31_000_001, 31_000_002, 31_000_003],
        most_active_wh_class: "C3"
      },
      security_risks: %{
        risk_score: 25,
        risk_factors: ["new_player"],
        corp_hopping_detected: false,
        suspicious_patterns: []
      },
      eviction_groups: %{
        eviction_group_detected: false,
        known_groups: [],
        confidence_score: 0.1
      },
      alt_character_patterns: %{
        potential_alts: [],
        shared_systems: [],
        timing_correlation: 0.2
      },
      competency_metrics: %{
        small_gang_performance: %{
          kill_efficiency: 0.8,
          avg_gang_size: 3.5,
          preferred_size: "small_gang",
          solo_capability: true
        }
      },
      recommendation: %{
        recommendation: "conditional",
        confidence: 0.75,
        reasoning: "Good J-space experience but limited history",
        conditions: ["Probationary period recommended", "Monitor activity closely"]
      },
      analysis_timestamp: DateTime.utc_now()
    }
  end
end
