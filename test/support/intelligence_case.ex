defmodule EveDmv.IntelligenceCase do
  @moduledoc """
  Base case for intelligence module testing
  """

  use ExUnit.CaseTemplate

  import EveDmv.Factories

  using do
    quote do
      use EveDmv.DataCase, async: true

      import EveDmv.Factories
      import EveDmv.IntelligenceCase

      alias EveDmv.Intelligence.{
        CharacterAnalyzer,
        HomeDefenseAnalyzer,
        MemberActivityAnalyzer,
        WHFleetAnalyzer
      }

      alias EveDmv.Intelligence.WHVettingAnalyzer
    end
  end

  def create_realistic_killmail_set(character_id, opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    days_back = Keyword.get(opts, :days_back, 30)

    for _i <- 1..count do
      create(:killmail_raw, %{
        victim_character_id: character_id,
        killmail_time: random_datetime_in_past(days_back)
      })
    end
  end

  def create_wormhole_activity(character_id, wh_class, opts \\ []) do
    # Create realistic wormhole activity patterns
    count = Keyword.get(opts, :count, 5)
    days_back = Keyword.get(opts, :days_back, 30)
    # :hunter, :victim, :mixed
    role = Keyword.get(opts, :role, :mixed)

    wh_system_id = get_wh_system_id(wh_class)
    ship_types = get_wh_ship_types(wh_class)

    for _i <- 1..count do
      killmail_time = random_datetime_in_past(days_back)

      killmail_data =
        build_wh_killmail_data(
          character_id,
          role,
          ship_types,
          wh_system_id,
          killmail_time
        )

      create(:killmail_raw, %{
        solar_system_id: wh_system_id,
        killmail_time: killmail_time,
        raw_data: killmail_data,
        victim_character_id: character_id
      })
    end
  end

  defp get_wh_system_id(wh_class) do
    # J-space system IDs for different wormhole classes
    case wh_class do
      "C1" -> Enum.random(31_000_000..31_001_000)
      "C2" -> Enum.random(31_001_000..31_002_000)
      "C3" -> Enum.random(31_002_000..31_003_000)
      "C4" -> Enum.random(31_003_000..31_004_000)
      "C5" -> Enum.random(31_004_000..31_005_000)
      "C6" -> Enum.random(31_005_000..31_006_000)
      _ -> Enum.random(31_000_000..31_006_000)
    end
  end

  defp get_wh_ship_types(wh_class) do
    # Select appropriate ship types for WH class
    case wh_class do
      # Frigates, cruisers
      c when c in ["C1", "C2", "C3"] -> [587, 588, 589, 624, 622]
      # T3 cruisers
      c when c in ["C4", "C5"] -> [17_738, 29_984, 29_986, 29_988]
      # Capitals
      "C6" -> [23_917, 23_919, 24_483, 19_720]
      _ -> [587, 588, 589]
    end
  end

  defp build_wh_killmail_data(character_id, role, ship_types, wh_system_id, killmail_time) do
    case role do
      :hunter -> build_hunter_killmail(character_id, ship_types, wh_system_id, killmail_time)
      :victim -> build_victim_killmail(character_id, ship_types, wh_system_id, killmail_time)
      :mixed -> build_mixed_killmail(character_id, ship_types, wh_system_id, killmail_time)
    end
  end

  defp build_hunter_killmail(character_id, ship_types, wh_system_id, killmail_time) do
    %{
      "victim" => %{
        "character_id" => Enum.random(90_000_000..100_000_000),
        "ship_type_id" => Enum.random(ship_types)
      },
      "attackers" => [
        %{
          "character_id" => character_id,
          "ship_type_id" => Enum.random(ship_types),
          "final_blow" => true
        }
      ],
      "killmail_time" => DateTime.to_iso8601(killmail_time),
      "solar_system_id" => wh_system_id
    }
  end

  defp build_victim_killmail(character_id, ship_types, wh_system_id, killmail_time) do
    %{
      "victim" => %{
        "character_id" => character_id,
        "ship_type_id" => Enum.random(ship_types)
      },
      "attackers" => [
        %{
          "character_id" => Enum.random(90_000_000..100_000_000),
          "ship_type_id" => Enum.random(ship_types),
          "final_blow" => true
        }
      ],
      "killmail_time" => DateTime.to_iso8601(killmail_time),
      "solar_system_id" => wh_system_id
    }
  end

  defp build_mixed_killmail(character_id, ship_types, wh_system_id, killmail_time) do
    if Enum.random([true, false]) do
      build_hunter_killmail(character_id, ship_types, wh_system_id, killmail_time)
    else
      build_victim_killmail(character_id, ship_types, wh_system_id, killmail_time)
    end
  end

  def create_pvp_pattern(character_id, pattern_type, opts \\ []) do
    case pattern_type do
      :hunter ->
        # Creates killmails where character is frequently the attacker
        create_hunter_pattern(character_id, opts)

      :victim ->
        # Creates killmails where character is frequently the victim
        create_victim_pattern(character_id, opts)

      :mixed ->
        # Creates a balanced mix of kills and losses
        create_mixed_pattern(character_id, opts)
    end
  end

  defp create_hunter_pattern(character_id, opts) do
    count = Keyword.get(opts, :count, 10)

    for _i <- 1..count do
      victim_id = Enum.random(90_000_000..100_000_000)

      create(:killmail_raw, %{
        killmail_data: %{
          "victim" => %{"character_id" => victim_id},
          "attackers" => [
            %{
              "character_id" => character_id,
              "final_blow" => true,
              # T3 cruisers
              "ship_type_id" => Enum.random([17_738, 29_984])
            }
          ],
          "killmail_time" => random_datetime_in_past(30)
        }
      })
    end
  end

  defp create_victim_pattern(character_id, opts) do
    count = Keyword.get(opts, :count, 10)

    for _i <- 1..count do
      attacker_id = Enum.random(90_000_000..100_000_000)

      create(:killmail_raw, %{
        killmail_data: %{
          "victim" => %{
            "character_id" => character_id,
            # Cheap ships
            "ship_type_id" => Enum.random([587, 588, 589])
          },
          "attackers" => [
            %{
              "character_id" => attacker_id,
              "final_blow" => true
            }
          ],
          "killmail_time" => random_datetime_in_past(30)
        }
      })
    end
  end

  defp create_mixed_pattern(character_id, opts) do
    kill_count = Keyword.get(opts, :kill_count, 5)
    loss_count = Keyword.get(opts, :loss_count, 5)

    create_hunter_pattern(character_id, count: kill_count)
    create_victim_pattern(character_id, count: loss_count)
  end

  def create_corporate_activity(corporation_id, opts \\ []) do
    member_count = Keyword.get(opts, :member_count, 10)
    killmails_per_member = Keyword.get(opts, :killmails_per_member, 5)

    members =
      for _i <- 1..member_count do
        %{
          character_id: Enum.random(90_000_000..100_000_000),
          corporation_id: corporation_id
        }
      end

    for member <- members do
      for _j <- 1..killmails_per_member do
        create(:killmail_raw, %{
          killmail_data: %{
            "victim" => %{
              "character_id" => member.character_id,
              "corporation_id" => corporation_id
            },
            "killmail_time" => random_datetime_in_past(30)
          }
        })
      end
    end

    members
  end

  def create_alliance_activity(alliance_id, opts \\ []) do
    corporation_count = Keyword.get(opts, :corporation_count, 3)
    members_per_corp = Keyword.get(opts, :members_per_corp, 5)

    corporations =
      for _i <- 1..corporation_count do
        Enum.random(1_000_000..2_000_000)
      end

    all_members =
      for corp_id <- corporations do
        members =
          create_corporate_activity(corp_id,
            member_count: members_per_corp,
            killmails_per_member: 3
          )

        # Update members to include alliance_id
        for member <- members do
          Map.put(member, :alliance_id, alliance_id)
        end
      end

    List.flatten(all_members)
  end

  def create_character_stats(character_id, opts \\ []) do
    alias EveDmv.Intelligence.CharacterStats
    alias EveDmv.Api

    # First create the basic character record (only fields accepted by create action)
    basic_params = %{
      character_id: character_id,
      character_name: Keyword.get(opts, :character_name, "Test Character #{character_id}"),
      corporation_id: Keyword.get(opts, :corporation_id, 98_000_001),
      corporation_name: Keyword.get(opts, :corporation_name, "Test Corporation"),
      alliance_id: Keyword.get(opts, :alliance_id, 99_000_001),
      alliance_name: Keyword.get(opts, :alliance_name, "Test Alliance")
    }

    character_stats = Ash.create!(CharacterStats, basic_params, domain: Api)

    # Then update with the actual stats data (using correct field names)
    update_params = %{
      total_kills: Keyword.get(opts, :kill_count, 10),
      total_losses: Keyword.get(opts, :loss_count, 5),
      solo_kills: Keyword.get(opts, :solo_kill_count, 3),
      solo_losses: Keyword.get(opts, :solo_loss_count, 2),
      dangerous_rating: Keyword.get(opts, :dangerous_rating, 3),

      # Performance metrics that exist in the schema
      isk_efficiency: Keyword.get(opts, :efficiency, 66.7),
      kill_death_ratio: Keyword.get(opts, :kd_ratio, 2.0),

      # Behavioral metrics
      aggression_index: Keyword.get(opts, :aggression_index, 5.0),
      avg_gang_size: Keyword.get(opts, :avg_gang_size, 2.5),

      # Analysis metadata
      last_calculated_at: DateTime.utc_now(),
      data_completeness: Keyword.get(opts, :completeness_score, 85)
    }

    Ash.update!(character_stats, update_params, domain: Api)
  end

  def create_mock_analytics_data(character_id) do
    # Create mock data that AdvancedAnalytics functions would return
    # This prevents the "Insufficient data" errors in tests

    # Mock behavioral analysis data
    behavioral_analysis = %{
      confidence_score: 0.8,
      patterns: %{
        anomaly_detection: %{anomaly_count: 2},
        activity_rhythm: %{consistency_score: 0.7},
        operational_patterns: %{strategic_thinking: 0.6},
        risk_progression: %{stability_score: 0.75}
      }
    }

    # Mock threat assessment data  
    threat_assessment = %{
      threat_indicators: %{
        combat_effectiveness: 0.7,
        tactical_sophistication: 0.6
      }
    }

    # Mock risk analysis data
    risk_analysis = %{
      advanced_risk_score: 0.3
    }

    # Store these in a simple cache/store for the test
    Process.put(:"behavioral_analysis_#{character_id}", behavioral_analysis)
    Process.put(:"threat_assessment_#{character_id}", threat_assessment)
    Process.put(:"risk_analysis_#{character_id}", risk_analysis)

    {behavioral_analysis, threat_assessment, risk_analysis}
  end
end
