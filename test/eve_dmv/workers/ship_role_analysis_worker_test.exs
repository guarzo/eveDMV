defmodule EveDmv.Workers.ShipRoleAnalysisWorkerTest do
  # Not async due to GenServer state
  use EveDmv.DataCase, async: false

  alias EveDmv.Workers.ShipRoleAnalysisWorker
  alias EveDmv.Repo
  import Ecto.Query

  setup do
    # Start the worker for testing
    {:ok, pid} = ShipRoleAnalysisWorker.start_link()

    # Stop it after test
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{worker_pid: pid}
  end

  describe "perform_analysis/0" do
    test "analyzes recent killmail data and updates ship roles" do
      # Insert test killmail data
      setup_test_killmail_data()

      # Run analysis
      {:ok, stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Verify stats
      assert is_integer(stats.duration_ms)
      assert is_integer(stats.ships_analyzed)
      assert is_integer(stats.killmails_processed)
      assert is_map(stats.cache_updates)
      assert is_map(stats.trends_detected)
      assert %DateTime{} = stats.completed_at

      # Verify ship role patterns were created/updated
      pattern_count = Repo.one(from(s in "ship_role_patterns", select: count(s.ship_type_id)))
      assert pattern_count > 0
    end

    test "handles empty killmail data gracefully" do
      # Ensure no recent killmail data
      Repo.delete_all("killmails_raw")

      # Run analysis
      {:ok, stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Should complete without errors
      assert stats.ships_analyzed == 0
      assert stats.killmails_processed == 0
    end

    test "skips ships with insufficient sample size" do
      # Insert single killmail (below minimum sample size)
      insert_test_killmail(999_001, %{
        "victim" => %{
          "ship_type_id" => 999_001,
          "items" => [%{"flag" => 27, "type_name" => "Small Laser", "type_id" => 1234}]
        }
      })

      # Run analysis
      {:ok, stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Should skip due to insufficient data
      assert stats.ships_analyzed == 0
    end

    test "calculates role distributions correctly" do
      # Insert multiple killmails for same ship with consistent roles
      ship_type_id = 999_002

      # Insert 6 DPS-focused killmails
      for i <- 1..6 do
        insert_test_killmail(999_000 + i, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => [
              %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
              %{"flag" => 28, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
              %{"flag" => 11, "type_name" => "Magnetic Field Stabilizer II", "type_id" => 2605}
            ]
          }
        })
      end

      # Run analysis
      {:ok, stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Should analyze 1 ship type
      assert stats.ships_analyzed == 1

      # Check the ship role pattern was created
      pattern =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == ^ship_type_id,
            select: %{
              ship_type_id: s.ship_type_id,
              primary_role: s.primary_role,
              confidence_score: s.confidence_score,
              sample_size: s.sample_size,
              last_analyzed: s.last_analyzed,
              role_distribution: s.role_distribution
            }
          )
        )

      assert pattern != nil
      assert pattern.primary_role == "dps"
      assert pattern.confidence_score != nil
      assert pattern.sample_size == 6
      assert pattern.last_analyzed != nil
    end
  end

  describe "worker lifecycle" do
    test "starts and accepts commands", %{worker_pid: pid} do
      assert Process.alive?(pid)

      # Should be able to get stats
      stats = ShipRoleAnalysisWorker.get_stats()
      assert is_map(stats)
    end

    test "can trigger immediate analysis", %{worker_pid: _pid} do
      # Setup test data
      setup_test_killmail_data()

      # Trigger immediate analysis
      {:ok, stats} = ShipRoleAnalysisWorker.analyze_now()

      assert is_map(stats)
      assert is_integer(stats.duration_ms)
    end
  end

  describe "role aggregation" do
    test "aggregates multiple role classifications correctly" do
      # This tests the private functions through the public interface
      ship_type_id = 999_003

      # Insert mixed role killmails
      # 4 DPS killmails
      for i <- 1..4 do
        insert_test_killmail(999_100 + i, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => [
              %{"flag" => 27, "type_name" => "Artillery Cannon", "type_id" => 1111}
            ]
          }
        })
      end

      # 2 Logistics killmails  
      for i <- 5..6 do
        insert_test_killmail(999_100 + i, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => [
              %{"flag" => 27, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301}
            ]
          }
        })
      end

      # Run analysis
      {:ok, _stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Check aggregated results
      pattern =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == ^ship_type_id,
            select: %{
              ship_type_id: s.ship_type_id,
              primary_role: s.primary_role,
              role_distribution: s.role_distribution
            }
          )
        )

      assert pattern != nil

      # Primary role should be DPS (more common)
      assert pattern.primary_role == "dps"

      # Role distribution should reflect the mix
      role_dist = pattern.role_distribution
      assert role_dist["dps"] > role_dist["logistics"]
      assert role_dist["logistics"] > 0.0
    end
  end

  describe "meta trend detection" do
    test "detects stable trends with consistent data" do
      ship_type_id = 999_004

      # Insert historical data
      yesterday = Date.utc_today() |> Date.add(-1)

      Repo.insert_all("role_analysis_history", [
        %{
          ship_type_id: ship_type_id,
          analysis_date: yesterday,
          role_distribution: %{
            "dps" => 0.8,
            "support" => 0.2,
            "logistics" => 0.0,
            "tackle" => 0.0,
            "ewar" => 0.0,
            "command" => 0.0
          },
          meta_indicators: %{},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])

      # Insert current killmails with same pattern (DPS focused)
      for i <- 1..5 do
        insert_test_killmail(999_200 + i, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => [
              %{"flag" => 27, "type_name" => "Beam Laser", "type_id" => 2222}
            ]
          }
        })
      end

      # Run analysis
      {:ok, _stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Check meta trend
      pattern =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == ^ship_type_id,
            select: %{
              ship_type_id: s.ship_type_id,
              meta_trend: s.meta_trend
            }
          )
        )

      assert pattern.meta_trend == "stable"
    end
  end

  describe "confidence scoring" do
    test "assigns higher confidence to consistent classifications" do
      ship_type_id = 999_005

      # Insert 8 very consistent DPS killmails
      for i <- 1..8 do
        insert_test_killmail(999_300 + i, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => [
              %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
              %{"flag" => 28, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
              %{"flag" => 29, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
            ]
          }
        })
      end

      # Run analysis
      {:ok, _stats} = ShipRoleAnalysisWorker.perform_analysis()

      # Check confidence score
      pattern =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == ^ship_type_id,
            select: %{
              ship_type_id: s.ship_type_id,
              primary_role: s.primary_role,
              confidence_score: s.confidence_score
            }
          )
        )

      confidence = Decimal.to_float(pattern.confidence_score)

      # Should have high confidence due to consistency and sample size
      assert confidence > 0.7
      assert pattern.primary_role == "dps"
    end
  end

  # Helper functions

  defp setup_test_killmail_data do
    # Create diverse test data
    # Megathron, Guardian, Sabre
    ship_types = [641, 11987, 22456]

    Enum.each(ship_types, fn ship_type_id ->
      # Insert 6 killmails per ship type (above minimum sample size)
      for i <- 1..6 do
        killmail_id = ship_type_id * 1000 + i

        items =
          case ship_type_id do
            # Megathron - DPS
            641 ->
              [
                %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
                %{"flag" => 11, "type_name" => "Magnetic Field Stabilizer II", "type_id" => 2605}
              ]

            # Guardian - Logistics
            11987 ->
              [
                %{
                  "flag" => 27,
                  "type_name" => "Large Remote Armor Repairer II",
                  "type_id" => 3301
                },
                %{
                  "flag" => 28,
                  "type_name" => "Remote Capacitor Transmitter II",
                  "type_id" => 3302
                }
              ]

            # Sabre - Tackle
            22456 ->
              [
                %{"flag" => 19, "type_name" => "Warp Scrambler II", "type_id" => 441},
                %{"flag" => 20, "type_name" => "Stasis Webifier II", "type_id" => 526}
              ]
          end

        insert_test_killmail(killmail_id, %{
          "victim" => %{
            "ship_type_id" => ship_type_id,
            "items" => items
          }
        })
      end
    end)
  end

  defp insert_test_killmail(killmail_id, raw_data) do
    killmail_time = DateTime.utc_now() |> DateTime.add(-:rand.uniform(6), :day)
    victim_ship_type_id = raw_data["victim"]["ship_type_id"]

    Repo.insert_all("killmails_raw", [
      %{
        killmail_id: killmail_id,
        killmail_time: killmail_time,
        killmail_hash: "test_hash_#{killmail_id}",
        # Jita
        solar_system_id: 30_000_142,
        victim_ship_type_id: victim_ship_type_id,
        attacker_count: 1,
        raw_data: raw_data,
        source: "test",
        inserted_at: DateTime.utc_now()
      }
    ])
  end
end
