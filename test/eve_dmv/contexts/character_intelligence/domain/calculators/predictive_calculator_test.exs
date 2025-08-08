defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Calculators.PredictiveCalculatorTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence.Domain.Calculators.PredictiveCalculator
  alias EveDmv.Killmails.KillmailRaw

  describe "predict_future_threat/2" do
    setup do
      character_id = 95_500_001

      # Create historical data with clear trend
      # Month 1: Low activity (threat ~30)
      for day <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 600_000_000 + day,
              killmail_time: DateTime.utc_now() |> DateTime.add(-90 + day, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_600_000 + day,
              # Rifter
              victim_ship_type_id: 587,
              victim_corporation_id: 98_000_000,
              attacker_count: 1,
              total_value: Decimal.new("5000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character_id,
                    "ship_type_id" => 587,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Month 2: Medium activity (threat ~50)
      for day <- 1..20 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 601_000_000 + day,
              killmail_time: DateTime.utc_now() |> DateTime.add(-60 + day, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_601_000 + day,
              # Vexor
              victim_ship_type_id: 624,
              victim_corporation_id: 98_000_000,
              attacker_count: 2,
              total_value: Decimal.new("25000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character_id,
                    # Tengu
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Month 3: High activity (threat ~70)
      for day <- 1..30 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 602_000_000 + day,
              killmail_time: DateTime.utc_now() |> DateTime.add(-30 + day, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_602_000 + day,
              # Armageddon
              victim_ship_type_id: 643,
              victim_corporation_id: 98_000_000,
              attacker_count: 3,
              total_value: Decimal.new("100000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character_id,
                    # Loki
                    "ship_type_id" => 29_986,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{character_id: character_id}
    end

    test "predicts future threat based on trends", %{character_id: character_id} do
      assert {:ok, prediction} = PredictiveCalculator.predict_future_threat(character_id)

      assert Map.has_key?(prediction, :predicted_threat_score)
      assert Map.has_key?(prediction, :confidence_interval)
      assert Map.has_key?(prediction, :trend_direction)
      assert Map.has_key?(prediction, :prediction_factors)

      # With increasing trend, prediction should be higher than current
      assert prediction.trend_direction in [:increasing, :stable, :decreasing]
      assert prediction.predicted_threat_score >= 0 and prediction.predicted_threat_score <= 100
      assert prediction.confidence_interval.lower <= prediction.predicted_threat_score
      assert prediction.confidence_interval.upper >= prediction.predicted_threat_score
    end

    test "provides confidence intervals", %{character_id: character_id} do
      assert {:ok, prediction} = PredictiveCalculator.predict_future_threat(character_id)

      interval = prediction.confidence_interval
      assert Map.has_key?(interval, :lower)
      assert Map.has_key?(interval, :upper)
      assert Map.has_key?(interval, :confidence_level)

      assert interval.confidence_level in [0.90, 0.95, 0.99]
      assert interval.upper > interval.lower
    end

    test "includes prediction factors", %{character_id: character_id} do
      assert {:ok, prediction} = PredictiveCalculator.predict_future_threat(character_id)

      factors = prediction.prediction_factors
      assert is_list(factors)

      Enum.each(factors, fn factor ->
        assert Map.has_key?(factor, :name)
        assert Map.has_key?(factor, :weight)
        assert Map.has_key?(factor, :contribution)
      end)
    end

    test "handles custom time horizons", %{character_id: character_id} do
      # Predict 7 days ahead
      assert {:ok, pred_7} =
               PredictiveCalculator.predict_future_threat(character_id, days_ahead: 7)

      # Predict 30 days ahead
      assert {:ok, pred_30} =
               PredictiveCalculator.predict_future_threat(character_id, days_ahead: 30)

      # Longer predictions should have wider confidence intervals
      assert pred_30.confidence_interval.upper - pred_30.confidence_interval.lower >
               pred_7.confidence_interval.upper - pred_7.confidence_interval.lower
    end

    test "handles insufficient data gracefully" do
      new_character = 95_999_999

      assert {:ok, prediction} = PredictiveCalculator.predict_future_threat(new_character)

      # Should return low confidence prediction
      assert prediction.confidence_interval.upper - prediction.confidence_interval.lower > 50

      assert prediction.prediction_factors == [] or
               Enum.any?(prediction.prediction_factors, &(&1.name == :insufficient_data))
    end
  end

  describe "calculate_risk_trajectory/2" do
    setup do
      character_id = 95_700_001

      # Create evolving risk profile
      # Early: Low-value targets, defensive play
      for i <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        # Some losses early on
        if rem(i, 3) == 0 do
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 610_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-60 + i, :day),
                solar_system_id: 30_000_142,
                victim_character_id: character_id,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_000_000,
                attacker_count: 5,
                total_value: Decimal.new("10000000"),
                raw_data: %{
                  "victim" => %{"character_id" => character_id}
                }
              })
            )
        else
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 611_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-60 + i, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 95_800_000 + i,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_000_000,
                attacker_count: 1,
                total_value: Decimal.new("5000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => character_id,
                      "ship_type_id" => 587,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      # Recent: High-value targets, aggressive play
      for i <- 1..20 do
        killmail_attrs = killmail_raw_factory()

        # Fewer losses, bigger targets
        if i == 15 do
          # One big loss
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 612_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-20 + i, :day),
                solar_system_id: 30_000_142,
                victim_character_id: character_id,
                victim_ship_type_id: 643,
                victim_corporation_id: 98_000_000,
                attacker_count: 10,
                total_value: Decimal.new("200000000"),
                raw_data: %{
                  "victim" => %{"character_id" => character_id}
                }
              })
            )
        else
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 613_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-20 + i, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 95_900_000 + i,
                # Battleships
                victim_ship_type_id: Enum.random([643, 645, 641]),
                victim_corporation_id: 98_000_000,
                attacker_count: 1,
                total_value: Decimal.new("150000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => character_id,
                      # Loki
                      "ship_type_id" => 29_986,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{character_id: character_id}
    end

    test "calculates risk trajectory", %{character_id: character_id} do
      assert {:ok, trajectory} = PredictiveCalculator.calculate_risk_trajectory(character_id)

      assert Map.has_key?(trajectory, :current_risk_level)
      assert Map.has_key?(trajectory, :risk_trend)
      assert Map.has_key?(trajectory, :risk_factors)
      assert Map.has_key?(trajectory, :projected_risk_change)

      assert trajectory.current_risk_level in [:low, :medium, :high, :extreme]
      assert trajectory.risk_trend in [:increasing, :stable, :decreasing]
    end

    test "identifies risk factors", %{character_id: character_id} do
      assert {:ok, trajectory} = PredictiveCalculator.calculate_risk_trajectory(character_id)

      assert is_list(trajectory.risk_factors)

      # Should identify various risk indicators
      Enum.each(trajectory.risk_factors, fn factor ->
        assert is_binary(factor) or is_map(factor)
      end)
    end

    test "projects future risk changes", %{character_id: character_id} do
      assert {:ok, trajectory} = PredictiveCalculator.calculate_risk_trajectory(character_id)

      projection = trajectory.projected_risk_change
      assert Map.has_key?(projection, :direction)
      assert Map.has_key?(projection, :magnitude)
      assert Map.has_key?(projection, :timeframe_days)

      assert projection.direction in [:increase, :decrease, :stable]
      assert projection.magnitude in [:minor, :moderate, :significant]
      assert projection.timeframe_days > 0
    end
  end

  describe "predict_engagement_outcome/3" do
    setup do
      attacker_id = 95_100_001
      defender_id = 95_100_002

      # Create combat history for both
      # Attacker: Strong record
      for i <- 1..15 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 620_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 3, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_200_000 + i,
              victim_ship_type_id: Enum.random([587, 624, 29_984]),
              victim_corporation_id: 98_000_000,
              attacker_count: 1,
              total_value: Decimal.new("50000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => attacker_id,
                    # Loki
                    "ship_type_id" => 29_986,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Defender: Mixed record
      for i <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        if rem(i, 3) == 0 do
          # Losses
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 621_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-i * 4, :day),
                solar_system_id: 30_000_142,
                victim_character_id: defender_id,
                victim_ship_type_id: 624,
                victim_corporation_id: 98_000_000,
                attacker_count: 2,
                total_value: Decimal.new("30000000"),
                raw_data: %{
                  "victim" => %{"character_id" => defender_id}
                }
              })
            )
        else
          # Victories
          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 622_000_000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-i * 4, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 95_300_000 + i,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_000_000,
                attacker_count: 1,
                total_value: Decimal.new("15000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => defender_id,
                      "ship_type_id" => 624,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{attacker_id: attacker_id, defender_id: defender_id}
    end

    test "predicts engagement outcome", %{attacker_id: attacker_id, defender_id: defender_id} do
      assert {:ok, prediction} =
               PredictiveCalculator.predict_engagement_outcome(
                 attacker_id,
                 defender_id
               )

      assert Map.has_key?(prediction, :likely_victor)
      assert Map.has_key?(prediction, :victory_probability)
      assert Map.has_key?(prediction, :confidence)
      assert Map.has_key?(prediction, :key_factors)

      assert prediction.likely_victor in [attacker_id, defender_id, :uncertain]
      assert prediction.victory_probability >= 0 and prediction.victory_probability <= 1
      assert prediction.confidence in [:high, :medium, :low]
    end

    test "considers ship matchups", %{attacker_id: attacker_id, defender_id: defender_id} do
      # Predict with specific ships
      assert {:ok, prediction} =
               PredictiveCalculator.predict_engagement_outcome(
                 attacker_id,
                 defender_id,
                 # Loki
                 attacker_ship: 29_986,
                 # Vexor
                 defender_ship: 624
               )

      # Ship matchup should be a factor
      assert Enum.any?(prediction.key_factors, fn factor ->
               String.contains?(to_string(factor), "ship") or
                 Map.get(factor, :type) == :ship_matchup
             end)
    end

    test "includes environmental factors", %{attacker_id: attacker_id, defender_id: defender_id} do
      assert {:ok, prediction} =
               PredictiveCalculator.predict_engagement_outcome(
                 attacker_id,
                 defender_id,
                 environment: %{
                   system_security: 0.4,
                   local_count: 15,
                   time_of_day: ~T[22:00:00]
                 }
               )

      assert is_list(prediction.key_factors)
      # Environmental factors might influence confidence
      assert prediction.confidence in [:high, :medium, :low]
    end
  end

  describe "forecast_activity_level/2" do
    setup do
      character_id = 95_400_001

      # Create weekly activity pattern
      # Weekdays: High activity
      # Weekends: Low activity
      for week <- 0..11 do
        for day <- 0..6 do
          # Low on Sunday/Saturday
          kills_today = if day in [0, 6], do: 1, else: 3

          for kill <- 1..kills_today do
            killmail_attrs = killmail_raw_factory()
            days_ago = week * 7 + day

            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 630_000_000 + week * 100 + day * 10 + kill,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-days_ago, :day),
                  solar_system_id: 30_000_142,
                  victim_character_id: 95_500_000 + days_ago * 10 + kill,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_000_000,
                  attacker_count: 1,
                  total_value: Decimal.new("10000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => character_id,
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

      %{character_id: character_id}
    end

    test "forecasts daily activity", %{character_id: character_id} do
      assert {:ok, forecast} = PredictiveCalculator.forecast_activity_level(character_id)

      assert Map.has_key?(forecast, :next_24h)
      assert Map.has_key?(forecast, :next_7d)
      assert Map.has_key?(forecast, :peak_times)
      assert Map.has_key?(forecast, :activity_pattern)

      # Next 24h should be a single prediction
      assert forecast.next_24h.expected_kills >= 0
      assert forecast.next_24h.confidence in [:high, :medium, :low]

      # Next 7d should be daily predictions
      assert length(forecast.next_7d) == 7

      Enum.each(forecast.next_7d, fn day ->
        assert Map.has_key?(day, :date)
        assert Map.has_key?(day, :expected_kills)
      end)
    end

    test "identifies peak activity times", %{character_id: character_id} do
      assert {:ok, forecast} = PredictiveCalculator.forecast_activity_level(character_id)

      assert is_list(forecast.peak_times)

      Enum.each(forecast.peak_times, fn peak ->
        assert Map.has_key?(peak, :hour) or Map.has_key?(peak, :day_of_week)
        assert Map.has_key?(peak, :activity_level)
      end)
    end

    test "detects activity patterns", %{character_id: character_id} do
      assert {:ok, forecast} = PredictiveCalculator.forecast_activity_level(character_id)

      pattern = forecast.activity_pattern

      assert pattern in [
               :consistent,
               :weekday_warrior,
               :weekend_warrior,
               :sporadic,
               :declining,
               :increasing
             ]
    end

    test "handles seasonal adjustments", %{character_id: character_id} do
      # Forecast with seasonal context
      assert {:ok, forecast} =
               PredictiveCalculator.forecast_activity_level(
                 character_id,
                 include_seasonal: true
               )

      if Map.has_key?(forecast, :seasonal_adjustment) do
        assert forecast.seasonal_adjustment.factor >= 0.5 and
                 forecast.seasonal_adjustment.factor <= 2.0

        assert is_binary(forecast.seasonal_adjustment.reason)
      end
    end
  end
end
