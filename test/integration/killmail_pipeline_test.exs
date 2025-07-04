defmodule EveDmv.Integration.KillmailPipelineTest do
  # Pipeline tests need isolation
  use EveDmv.DataCase, async: false

  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterAnalysis.CharacterAnalyzer
  alias EveDmv.Killmails
  alias EveDmv.Killmails.{KillmailEnriched, KillmailPipeline, KillmailRaw, Participant}

  require Ash.Query

  describe "end-to-end killmail processing" do
    @describetag :integration
    test "processes killmail from ingestion to intelligence" do
      # Create realistic killmail data
      raw_killmail = build_realistic_killmail()

      # Process through pipeline stages manually
      # 1. Transform SSE event
      sse_event = %{event: "killmail", data: Jason.encode!(raw_killmail)}
      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert length(messages) == 1
      [message] = messages

      # 2. Handle message (processing stage)
      processed_message = KillmailPipeline.handle_message(:default, message, %{})
      assert processed_message.status == :ok
      {_raw_changeset, _enriched_changeset, _participants} = processed_message.data

      # 3. Simulate batch handling
      result = KillmailPipeline.handle_batch(:db_insert, [processed_message], %{}, %{})
      assert is_list(result)
      assert length(result) == 1

      # Verify data was inserted correctly
      killmail_id = raw_killmail["killmail_id"]

      # Check raw killmail
      raw_query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id == ^killmail_id)

      assert {:ok, [raw_km]} = Ash.read(raw_query, domain: Api)
      assert raw_km.killmail_id == killmail_id
      assert raw_km.source == "wanderer-kills"

      # Check enriched killmail
      enriched_query =
        KillmailEnriched
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id == ^killmail_id)

      assert {:ok, [enriched_km]} = Ash.read(enriched_query, domain: Api)
      assert enriched_km.victim_character_name != nil

      # Check participants
      participants_query =
        Participant
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id == ^killmail_id)

      assert {:ok, participants} = Ash.read(participants_query, domain: Api)
      assert length(participants) > 0

      # Verify intelligence update would work
      character_id = raw_killmail["victim"]["character_id"]

      # Note: CharacterAnalyzer requires minimum activity, so we create more killmails
      create_minimum_activity_for_character(character_id)

      {:ok, stats} = CharacterAnalyzer.analyze_character(character_id)
      assert stats.loss_count >= 1
    end

    test "handles malformed killmail data gracefully" do
      malformed_killmail = %{
        "killmail_id" => 123,
        "killmail_data" => %{"invalid" => "structure"}
      }

      # Transform should handle this
      sse_event = %{event: "killmail", data: Jason.encode!(malformed_killmail)}
      messages = KillmailPipeline.transform_sse(sse_event, [])

      # Should still create a message but it will fail in processing
      assert length(messages) == 1
      [message] = messages

      # Process message
      processed = KillmailPipeline.handle_message(:default, message, %{})

      # Should either fail or handle gracefully
      assert processed.status in [:ok, :failed]
    end

    test "processes batch of killmails efficiently" do
      # Create multiple killmails
      killmails =
        for i <- 1..5 do
          build_realistic_killmail(killmail_id: 90_000_000 + i)
        end

      # Transform all to messages
      messages =
        Enum.flat_map(killmails, fn km ->
          sse_event = %{event: "killmail", data: Jason.encode!(km)}
          KillmailPipeline.transform_sse(sse_event, [])
        end)

      assert length(messages) == 5

      # Process all messages
      processed_messages =
        Enum.map(messages, fn msg ->
          KillmailPipeline.handle_message(:default, msg, %{})
        end)

      # Batch insert
      result = KillmailPipeline.handle_batch(:db_insert, processed_messages, %{}, %{})
      assert length(result) == 5

      # Verify all were inserted
      killmail_ids = Enum.map(killmails, & &1["killmail_id"])

      raw_query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id in ^killmail_ids)

      assert {:ok, raw_killmails} = Ash.read(raw_query, domain: Api)
      assert length(raw_killmails) == 5
    end

    test "handles SSE connection events" do
      # Test "connected" event
      connected_event = %{event: "connected", data: "Connected to SSE stream"}
      messages = KillmailPipeline.transform_sse(connected_event, [])
      assert messages == []

      # Test unknown event
      unknown_event = %{event: "heartbeat", data: "{}"}
      messages = KillmailPipeline.transform_sse(unknown_event, [])
      assert messages == []
    end

    test "handles JSON parsing errors" do
      # Invalid JSON
      invalid_event = %{event: "killmail", data: "not json"}
      messages = KillmailPipeline.transform_sse(invalid_event, [])
      assert messages == []

      # Valid JSON but not a killmail
      non_killmail_event = %{event: "killmail", data: Jason.encode!(%{"some" => "data"})}
      messages = KillmailPipeline.transform_sse(non_killmail_event, [])
      assert messages == []
    end

    test "enriches killmail with proper data" do
      raw_killmail = build_realistic_killmail()

      # Process through pipeline
      sse_event = %{event: "killmail", data: Jason.encode!(raw_killmail)}
      [message] = KillmailPipeline.transform_sse(sse_event, [])
      processed = KillmailPipeline.handle_message(:default, message, %{})

      {_raw, enriched_changeset, _participants} = processed.data

      # Check enriched data
      assert enriched_changeset.victim_character_name != nil
      assert enriched_changeset.victim_ship_name != nil
      assert enriched_changeset.final_blow_character_name != nil
      assert enriched_changeset.final_blow_ship_name != nil
      assert enriched_changeset.total_value != nil
    end

    test "creates proper participant records" do
      raw_killmail = build_realistic_killmail(attacker_count: 3)

      # Process through pipeline
      sse_event = %{event: "killmail", data: Jason.encode!(raw_killmail)}
      [message] = KillmailPipeline.transform_sse(sse_event, [])
      processed = KillmailPipeline.handle_message(:default, message, %{})

      {_raw, _enriched, participants} = processed.data

      # Should have victim + 3 attackers = 4 participants
      assert length(participants) == 4

      # Check victim
      victim = Enum.find(participants, & &1.is_victim)
      assert victim != nil
      assert victim.character_id == raw_killmail["victim"]["character_id"]

      # Check attackers
      attackers = Enum.reject(participants, & &1.is_victim)
      assert length(attackers) == 3

      # Check final blow
      final_blow = Enum.find(attackers, & &1.final_blow)
      assert final_blow != nil
    end

    test "handles duplicate killmail insertion" do
      raw_killmail = build_realistic_killmail()

      # Process same killmail twice
      sse_event = %{event: "killmail", data: Jason.encode!(raw_killmail)}

      for _i <- 1..2 do
        [message] = KillmailPipeline.transform_sse(sse_event, [])
        processed = KillmailPipeline.handle_message(:default, message, %{})
        KillmailPipeline.handle_batch(:db_insert, [processed], %{}, %{})
      end

      # Should only have one record
      killmail_id = raw_killmail["killmail_id"]

      raw_query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id == ^killmail_id)

      assert {:ok, killmails} = Ash.read(raw_query, domain: Api)
      assert length(killmails) == 1
    end
  end

  describe "telemetry events" do
    test "emits telemetry for successful processing" do
      :telemetry.attach(
        "test-success",
        [:eve_dmv, :killmail, :processed],
        fn _event, measurements, _metadata, _config ->
          send(self(), {:telemetry, :processed, measurements})
        end,
        nil
      )

      raw_killmail = build_realistic_killmail()
      sse_event = %{event: "killmail", data: Jason.encode!(raw_killmail)}
      [message] = KillmailPipeline.transform_sse(sse_event, [])
      KillmailPipeline.handle_message(:default, message, %{})

      assert_receive {:telemetry, :processed, %{count: 1}}

      :telemetry.detach("test-success")
    end

    test "emits telemetry for failed processing" do
      :telemetry.attach(
        "test-failure",
        [:eve_dmv, :killmail, :failed],
        fn _event, measurements, _metadata, _config ->
          send(self(), {:telemetry, :failed, measurements})
        end,
        nil
      )

      # Create a message that will fail
      invalid_message = %Broadway.Message{
        data: %{"invalid" => "data"},
        acknowledger: Broadway.NoopAcknowledger.init()
      }

      KillmailPipeline.handle_message(:default, invalid_message, %{})

      assert_receive {:telemetry, :failed, %{count: 1}}

      :telemetry.detach("test-failure")
    end
  end

  # Helper functions

  defp build_realistic_killmail(opts \\ []) do
    killmail_id = Keyword.get(opts, :killmail_id, System.unique_integer([:positive]) + 80_000_000)
    attacker_count = Keyword.get(opts, :attacker_count, 1)

    victim_character_id = Enum.random(90_000_000..100_000_000)

    # Build attackers
    attackers =
      for i <- 1..attacker_count do
        %{
          "character_id" => Enum.random(90_000_000..100_000_000),
          "character_name" => "Attacker #{i}",
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "corporation_name" => "Corp #{i}",
          "alliance_id" =>
            if(Enum.random(0..1) == 1, do: Enum.random(99_000_000..100_000_000), else: nil),
          "alliance_name" => if(Enum.random(0..1) == 1, do: "Alliance #{i}", else: nil),
          "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
          "ship_name" => Enum.random(["Rifter", "Rupture", "Stabber", "Loki"]),
          "weapon_type_id" => Enum.random([2185, 2873, 2961]),
          "damage_done" => Enum.random(100..5000),
          "final_blow" => i == 1
        }
      end

    %{
      "killmail_id" => killmail_id,
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      "solar_system_name" => "Jita",
      "moon_id" => nil,
      "war_id" => nil,
      "is_npc" => false,
      "is_solo" => attacker_count == 1,
      "victim" => %{
        "character_id" => victim_character_id,
        "character_name" => "Victim Pilot",
        "corporation_id" => Enum.random(1_000_000..2_000_000),
        "corporation_name" => "Victim Corp",
        "alliance_id" => nil,
        "alliance_name" => nil,
        "faction_id" => nil,
        "faction_name" => nil,
        "ship_type_id" => 587,
        "ship_name" => "Rifter",
        "damage_taken" => Enum.random(1000..10_000),
        "items" => [
          %{
            "item_type_id" => 2185,
            "item_name" => "150mm Light AutoCannon II",
            "flag" => 27,
            "quantity_destroyed" => 2,
            "quantity_dropped" => 0,
            "singleton" => 0
          }
        ]
      },
      "attackers" => attackers,
      "zkb" => %{
        "locationID" => 60_003_760,
        "hash" => Base.encode16(:crypto.strong_rand_bytes(20)),
        "fittedValue" => Enum.random(1_000_000..10_000_000),
        "droppedValue" => Enum.random(0..1_000_000),
        "destroyedValue" => Enum.random(500_000..5_000_000),
        "totalValue" => Enum.random(1_000_000..15_000_000),
        "points" => Enum.random(1..100),
        "npc" => false,
        "solo" => attacker_count == 1,
        "awox" => false
      }
    }
  end

  defp get_enriched_killmail(killmail_id) do
    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id == ^killmail_id)

    case Ash.read_one(query, domain: Api) do
      {:ok, killmail} -> killmail
      _ -> nil
    end
  end

  defp create_minimum_activity_for_character(character_id) do
    # CharacterAnalyzer requires at least 10 killmails
    for i <- 1..10 do
      killmail = build_realistic_killmail(killmail_id: 91_000_000 + i)

      # Make some kills and some losses
      killmail =
        if rem(i, 3) == 0 do
          # Make this a loss
          put_in(killmail, ["victim", "character_id"], character_id)
        else
          # Make this a kill
          attacker = hd(killmail["attackers"])
          updated_attacker = Map.put(attacker, "character_id", character_id)
          Map.put(killmail, "attackers", [updated_attacker | tl(killmail["attackers"])])
        end

      # Process through pipeline
      sse_event = %{event: "killmail", data: Jason.encode!(killmail)}
      [message] = KillmailPipeline.transform_sse(sse_event, [])
      processed = KillmailPipeline.handle_message(:default, message, %{})
      KillmailPipeline.handle_batch(:db_insert, [processed], %{}, %{})
    end
  end
end
