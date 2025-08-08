defmodule EveDmv.Contexts.CharacterIntelligenceDebugTest do
  use EveDmv.DataCase, async: false

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw

  require Ash.Query
  require Logger

  describe "debug threat analysis" do
    test "investigate data retrieval" do
      character_id = 95_123_456

      # Create a killmail with known data
      killmail_attrs = killmail_raw_factory()

      {:ok, killmail} =
        Api.create(
          KillmailRaw,
          Map.merge(killmail_attrs, %{
            killmail_id: 999_999_999,
            killmail_time: DateTime.utc_now() |> DateTime.add(-10, :day),
            solar_system_id: 30_000_142,
            victim_character_id: character_id,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_999,
            victim_alliance_id: nil,
            attacker_count: 1,
            total_value: Decimal.new("50000000.0"),
            raw_data: %{
              "victim" => %{"character_id" => character_id},
              "attackers" => [
                %{
                  "character_id" => 95_888_888,
                  "ship_type_id" => 24_696,
                  "final_blow" => true
                }
              ]
            }
          })
        )

      Logger.info("Created killmail: #{inspect(killmail.killmail_id)}")

      # Try to query it directly
      query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(victim_character_id == ^character_id)

      {:ok, results} = Api.read(query)
      Logger.info("Direct query found #{length(results)} killmails")

      # Try with time filter
      cutoff_date = DateTimeUtils.add(DateTime.utc_now(), -90, :day)

      query_with_time =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(victim_character_id == ^character_id)
        |> Ash.Query.filter(killmail_time >= ^cutoff_date)

      {:ok, results_with_time} = Api.read(query_with_time)
      Logger.info("Query with time filter found #{length(results_with_time)} killmails")

      # Now try the actual threat analysis
      result = CharacterIntelligence.analyze_character_threat(character_id)
      Logger.info("Threat analysis result: #{inspect(result)}")

      # Create more killmails to meet minimum requirement
      for i <- 1..10 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 999_900_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i, :day),
              solar_system_id: 30_000_142,
              victim_character_id: if(rem(i, 2) == 0, do: character_id, else: 95_888_888),
              victim_ship_type_id: 587,
              victim_corporation_id: 98_999_999,
              attacker_count: 1,
              total_value: Decimal.new("10000000.0"),
              raw_data: %{
                "victim" => %{
                  "character_id" => if(rem(i, 2) == 0, do: character_id, else: 95_888_888)
                },
                "attackers" => [
                  %{
                    "character_id" => if(rem(i, 2) == 0, do: 95_777_777, else: character_id),
                    "ship_type_id" => 24_696,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Query again
      {:ok, all_results} = Api.read(query)
      Logger.info("After creating 10 more, found #{length(all_results)} killmails")

      # Try threat analysis again
      result2 = CharacterIntelligence.analyze_character_threat(character_id)
      Logger.info("Second threat analysis result: #{inspect(result2)}")

      # If still failing, let's see what the minimum requirement is
      case result2 do
        {:error, :insufficient_data} ->
          Logger.error("Still insufficient data. Minimum required is 5 killmails")

        {:ok, analysis} ->
          assert analysis.character_id == character_id
          assert analysis.threat_score >= 0
          Logger.info("Success! Threat score: #{analysis.threat_score}")
      end
    end
  end
end
