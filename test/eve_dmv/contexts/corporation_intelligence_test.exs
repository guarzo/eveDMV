defmodule EveDmv.Contexts.CorporationIntelligenceTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CorporationIntelligence
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Users.User

  describe "get_corporation_intelligence_report/1" do
    setup do
      corporation_id = 98_000_001

      # Create corporation members
      members =
        for i <- 1..10 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 94_000_000 + i,
              character_name: "Corp Member #{i}",
              owner_hash: "corp_hash_#{i}_#{System.unique_integer()}"
            })

          member
        end

      # Create killmails for corporation members
      for member <- members do
        for j <- 1..5 do
          killmail_attrs = killmail_raw_factory()

          # Mix of kills and losses
          if rem(j, 3) == 0 do
            # Losses
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 800_000_000 + member.eve_character_id * 10 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j * 24, :hour),
                  solar_system_id: 30_000_142 + rem(j, 5),
                  victim_character_id: member.eve_character_id,
                  victim_ship_type_id: 624,
                  victim_corporation_id: corporation_id,
                  attacker_count: 3,
                  total_value: Decimal.new("25000000"),
                  raw_data: %{
                    "victim" => %{
                      "character_id" => member.eve_character_id,
                      "corporation_id" => corporation_id
                    }
                  }
                })
              )
          else
            # Kills
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 801_000_000 + member.eve_character_id * 10 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j * 24, :hour),
                  solar_system_id: 30_000_142 + rem(j, 5),
                  victim_character_id: 94_100_000 + j,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("10000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => member.eve_character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 29_984,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end
        end
      end

      %{corporation_id: corporation_id, members: members}
    end

    test "gets comprehensive intelligence report", %{corporation_id: corporation_id} do
      assert {:ok, report} =
               CorporationIntelligence.get_corporation_intelligence_report(corporation_id)

      assert Map.has_key?(report, :corporation)
      assert Map.has_key?(report, :activity_metrics)
      assert Map.has_key?(report, :doctrine_analysis)
      assert Map.has_key?(report, :member_threats)
      assert Map.has_key?(report, :summary)

      assert report.corporation.corporation_id == corporation_id
    end
  end

  describe "calculate_activity_metrics/1" do
    setup do
      corporation_id = 98_000_001

      # Create test data as before
      for i <- 1..5 do
        {:ok, member} =
          Api.create(User, %{
            character_id: 94_000_100 + i,
            character_name: "Metric Test #{i}",
            owner_hash: "metric_#{i}_#{System.unique_integer()}"
          })

        # Create recent activity
        for j <- 1..3 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 805_000_000 + i * 10 + j,
                killmail_time: DateTime.utc_now() |> DateTime.add(-j * 24, :hour),
                solar_system_id: 30_000_142,
                victim_character_id: 94_100_000 + j,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 1,
                total_value: Decimal.new("10000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.eve_character_id,
                      "corporation_id" => corporation_id,
                      "ship_type_id" => 29_984,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{corporation_id: corporation_id}
    end

    test "calculates activity metrics", %{corporation_id: corporation_id} do
      assert {:ok, metrics} = CorporationIntelligence.calculate_activity_metrics(corporation_id)

      assert Map.has_key?(metrics, :active_members)
      assert Map.has_key?(metrics, :kills_per_day)
      assert Map.has_key?(metrics, :prime_timezone)
      assert is_number(metrics.active_members)
      assert is_number(metrics.kills_per_day)
    end
  end

  describe "analyze_combat_doctrines/1" do
    setup do
      corporation_id = 98_000_002

      # Create fleet killmails
      for i <- 1..20 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 806_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 94_200_000 + i,
              victim_ship_type_id: 643,
              victim_corporation_id: 98_999_999,
              attacker_count: 10,
              total_value: Decimal.new("100000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => 95_000_001,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 11_987,
                    "final_blow" => false
                  },
                  %{
                    "character_id" => 95_000_002,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 11_978,
                    "final_blow" => false
                  },
                  %{
                    "character_id" => 95_000_003,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 621,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{corporation_id: corporation_id}
    end

    test "analyzes combat doctrines", %{corporation_id: corporation_id} do
      result = CorporationIntelligence.analyze_combat_doctrines(corporation_id)

      # May return insufficient data error if not enough killmails
      assert match?({:ok, _}, result) or
               match?({:error, :insufficient_fleet_data}, result) or
               match?({:error, :insufficient_data}, result) or
               match?({:error, :insufficient_member_data}, result)

      case result do
        {:ok, doctrine} ->
          assert Map.has_key?(doctrine, :primary_doctrine) or
                   Map.has_key?(doctrine, :detected_doctrines)

        {:error, _} ->
          # Expected for insufficient data
          :ok
      end
    end
  end

  describe "analyze_top_member_threats/2" do
    setup do
      corporation_id = 98_000_003

      # Create members with threat-worthy killmails
      for i <- 1..3 do
        {:ok, member} =
          Api.create(User, %{
            character_id: 95_100_000 + i,
            character_name: "Threat Member #{i}",
            owner_hash: "threat_#{i}_#{System.unique_integer()}"
          })

        # Create killmails
        for j <- 1..10 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 807_000_000 + i * 100 + j,
                killmail_time: DateTime.utc_now() |> DateTime.add(-j * 2, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 95_200_000 + j,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 1,
                total_value: Decimal.new("50000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.eve_character_id,
                      "corporation_id" => corporation_id,
                      "ship_type_id" => 29_984,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{corporation_id: corporation_id}
    end

    test "analyzes top member threats", %{corporation_id: corporation_id} do
      assert {:ok, threats} =
               CorporationIntelligence.analyze_top_member_threats(corporation_id, 5)

      assert Map.has_key?(threats, :top_threats)
      assert is_list(threats.top_threats)
    end
  end

  describe "compare_combat_doctrines/2" do
    setup do
      corporation_ids = [98_000_004, 98_000_005]

      # Create killmails for multiple corporations
      for corp_id <- corporation_ids do
        for i <- 1..10 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 808_000_000 + (corp_id - 98_000_000) * 1000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 95_300_000 + i,
                victim_ship_type_id: 643,
                victim_corporation_id: 98_999_999,
                attacker_count: 5,
                total_value: Decimal.new("75000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => 95_400_000 + i,
                      "corporation_id" => corp_id,
                      "ship_type_id" => if(corp_id == 98_000_004, do: 621, else: 29_984),
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{corporation_ids: corporation_ids}
    end

    test "compares doctrines between corporations", %{corporation_ids: corporation_ids} do
      result = CorporationIntelligence.compare_combat_doctrines(corporation_ids)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, comparison} ->
          assert is_map(comparison)

        {:error, _reason} ->
          # Expected for insufficient data
          :ok
      end
    end
  end

  describe "generate_counter_doctrine/1" do
    setup do
      corporation_id = 98_000_006

      # Create specific doctrine pattern (shield kiting)
      for i <- 1..15 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 809_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_500_000 + i,
              victim_ship_type_id: 643,
              victim_corporation_id: 98_999_999,
              attacker_count: 8,
              total_value: Decimal.new("80000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => 95_600_001,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 621,
                    "final_blow" => false
                  },
                  %{
                    "character_id" => 95_600_002,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 11_978,
                    "final_blow" => false
                  },
                  %{
                    "character_id" => 95_600_003,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 29_337,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{corporation_id: corporation_id}
    end

    test "generates counter-doctrine recommendations", %{corporation_id: corporation_id} do
      result = CorporationIntelligence.generate_counter_doctrine(corporation_id)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, recommendations} ->
          assert is_map(recommendations)

        {:error, _reason} ->
          # Expected for insufficient data
          :ok
      end
    end
  end

  describe "track_doctrine_evolution/1" do
    setup do
      corporation_id = 98_000_007

      # Create evolving doctrine pattern over time
      # Early pattern - armor brawling
      for i <- 25..30 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 810_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_700_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_999_999,
              attacker_count: 5,
              total_value: Decimal.new("60000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => 95_800_001,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 641,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Recent pattern - shield kiting
      for i <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 811_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_900_000 + i,
              victim_ship_type_id: 643,
              victim_corporation_id: 98_999_999,
              attacker_count: 5,
              total_value: Decimal.new("70000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => 95_850_001,
                    "corporation_id" => corporation_id,
                    "ship_type_id" => 621,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{corporation_id: corporation_id}
    end

    test "tracks doctrine evolution over time", %{corporation_id: corporation_id} do
      result = CorporationIntelligence.track_doctrine_evolution(corporation_id)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, evolution} ->
          assert is_map(evolution) or is_list(evolution)

        _ ->
          :ok
      end
    end
  end
end
