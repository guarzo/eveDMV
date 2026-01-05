defmodule EveDmv.Integration.SurveillanceFlowTest do
  @moduledoc """
  Integration tests for the complete surveillance flow.

  Tests the full workflow from profile creation through entity matching,
  alert generation, and real-time updates.
  """

  use EveDmv.DataCase, async: false

  import EveDmv.GenServerTestHelper

  alias EveDmv.Contexts.Surveillance.Api, as: SurveillanceApi
  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository

  require Logger

  # =============================================================================
  # Setup and Helper Functions
  # =============================================================================

  setup do
    # IMPORTANT: Start GenServers in the correct order
    # ProfileRepository MUST be started before MatchingEngine
    # because MatchingEngine.init/1 calls ProfileRepository.get_active_profiles/0

    # Use the GenServer test helper to start in correct order with sandbox access
    {:ok, _pids} =
      start_genservers_in_order([
        {ProfileRepository, []},
        {MatchingEngine, []},
        {NotificationService, []}
      ])

    # Subscribe to PubSub for real-time updates testing
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:alerts")

    # Create a test user ID
    user_id = System.unique_integer([:positive])

    # Note: cleanup is handled automatically by start_genservers_in_order
    {:ok, user_id: user_id}
  end

  # =============================================================================
  # 1. Profile Creation Tests
  # =============================================================================

  describe "profile creation" do
    test "creates a character watch profile with valid data", %{user_id: user_id} do
      target_character_id = character_id()

      profile_data = %{
        name: "Watch Test Character #{System.unique_integer([:positive])}",
        criteria: %{
          type: :character_watch,
          character_ids: [target_character_id]
        },
        user_id: user_id,
        description: "Watching for a specific character"
      }

      assert {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.name == profile_data.name
      assert profile.criteria.type == :character_watch
      assert profile.criteria.character_ids == [target_character_id]
      assert profile.user_id == user_id
      assert profile.is_active == false
    end

    test "creates a corporation watch profile with valid data", %{user_id: user_id} do
      target_corporation_id = corporation_id()

      profile_data = %{
        name: "Watch Test Corporation #{System.unique_integer([:positive])}",
        criteria: %{
          type: :corporation_watch,
          corporation_ids: [target_corporation_id]
        },
        user_id: user_id
      }

      assert {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.criteria.type == :corporation_watch
      assert profile.criteria.corporation_ids == [target_corporation_id]
    end

    test "creates a system watch profile with valid data", %{user_id: user_id} do
      # Jita (30000142), Amarr (30002187), Dodixie (30003715)
      target_system_ids = [30_000_142, 30_002_187]

      profile_data = %{
        name: "Watch Systems #{System.unique_integer([:positive])}",
        criteria: %{
          type: :system_watch,
          system_ids: target_system_ids
        },
        user_id: user_id
      }

      assert {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.criteria.type == :system_watch
      assert profile.criteria.system_ids == target_system_ids
    end

    test "creates a ship type watch profile with valid data", %{user_id: user_id} do
      # Watch for specific ship types (frigates)
      target_ship_type_ids = [587, 588, 589]

      profile_data = %{
        name: "Watch Ship Types #{System.unique_integer([:positive])}",
        criteria: %{
          type: :ship_type_watch,
          ship_type_ids: target_ship_type_ids
        },
        user_id: user_id
      }

      assert {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.criteria.type == :ship_type_watch
      assert profile.criteria.ship_type_ids == target_ship_type_ids
    end

    test "creates an alliance watch profile with valid data", %{user_id: user_id} do
      target_alliance_id = Enum.random(99_000_000..100_000_000)

      profile_data = %{
        name: "Watch Alliance #{System.unique_integer([:positive])}",
        criteria: %{
          type: :alliance_watch,
          alliance_ids: [target_alliance_id]
        },
        user_id: user_id
      }

      assert {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.criteria.type == :alliance_watch
      assert profile.criteria.alliance_ids == [target_alliance_id]
    end

    test "rejects profile with missing required fields", %{user_id: _user_id} do
      # Missing name
      profile_data = %{
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: 1
      }

      assert {:error, _reason} = SurveillanceApi.create_profile(profile_data)
    end

    test "rejects profile with invalid name (too short)", %{user_id: user_id} do
      profile_data = %{
        name: "AB",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      assert {:error, :name_too_short} = SurveillanceApi.create_profile(profile_data)
    end

    test "rejects profile with invalid name (too long)", %{user_id: user_id} do
      long_name = String.duplicate("a", 101)

      profile_data = %{
        name: long_name,
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      assert {:error, :name_too_long} = SurveillanceApi.create_profile(profile_data)
    end

    test "rejects profile with invalid user_id", %{user_id: _user_id} do
      profile_data = %{
        name: "Valid Name",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: -1
      }

      assert {:error, :invalid_user_id} = SurveillanceApi.create_profile(profile_data)
    end

    test "enables and disables a profile", %{user_id: user_id} do
      profile_data = %{
        name: "Toggle Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      assert profile.is_active == false

      # Enable profile
      {:ok, enabled_profile} = SurveillanceApi.enable_profile(profile.id)
      assert enabled_profile.is_active == true

      # Disable profile
      {:ok, disabled_profile} = SurveillanceApi.disable_profile(profile.id)
      assert disabled_profile.is_active == false
    end

    test "updates profile criteria", %{user_id: user_id} do
      profile_data = %{
        name: "Update Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Update criteria to watch additional characters
      new_criteria = %{type: :character_watch, character_ids: [12345, 67890]}

      {:ok, updated_profile} =
        SurveillanceApi.update_profile(profile.id, %{criteria: new_criteria})

      assert updated_profile.criteria.character_ids == [12345, 67890]
    end

    test "deletes a profile", %{user_id: user_id} do
      profile_data = %{
        name: "Delete Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Delete profile
      assert :ok = SurveillanceApi.delete_profile(profile.id)

      # Verify profile is deleted (error code is :profile_not_found)
      assert {:error, :profile_not_found} = SurveillanceApi.get_profile(profile.id)
    end

    test "lists profiles for a user", %{user_id: user_id} do
      # Create multiple profiles for the same user
      created_profiles =
        for i <- 1..3 do
          profile_data = %{
            name: "List Test #{i} - #{System.unique_integer([:positive])}",
            criteria: %{type: :character_watch, character_ids: [12345 + i]},
            user_id: user_id
          }

          {:ok, profile} = SurveillanceApi.create_profile(profile_data)
          profile
        end

      # Verify we created 3 profiles
      assert length(created_profiles) == 3

      # List profiles for user (include inactive since new profiles default to inactive)
      {:ok, profiles} = SurveillanceApi.list_profiles(user_id: user_id, active_only: false)

      # Should have at least the 3 we created
      assert length(profiles) >= 3
      assert Enum.all?(profiles, fn p -> p.user_id == user_id end)
    end
  end

  # =============================================================================
  # 2. Entity Matching Tests
  # =============================================================================

  describe "entity matching" do
    test "matches killmail against character watch profile", %{user_id: user_id} do
      target_character_id = character_id()

      # Create profile watching for target character
      profile_data = %{
        name: "Character Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      # Create killmail with target character as victim
      killmail_event =
        build_killmail_event(
          victim_character_id: target_character_id,
          victim_corporation_id: corporation_id(),
          victim_ship_type_id: 587
        )

      # Match killmail against profile
      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == true
      assert match_result.profile_id == profile.id
      assert match_result.match_confidence >= 0.8
    end

    test "matches killmail when character is attacker", %{user_id: user_id} do
      target_character_id = character_id()

      profile_data = %{
        name: "Attacker Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      # Create killmail with target character as attacker
      killmail_event =
        build_killmail_event(
          victim_character_id: character_id(),
          attackers: [
            %{
              character_id: target_character_id,
              corporation_id: corporation_id(),
              ship_type_id: 588,
              final_blow: true
            }
          ]
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == true
      assert Enum.any?(match_result.matched_criteria, fn c -> c.type == :attacker end)
    end

    test "does not match killmail with non-matching character", %{user_id: user_id} do
      target_character_id = character_id()
      other_character_id = character_id()

      profile_data = %{
        name: "Non-Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      # Create killmail without target character
      killmail_event =
        build_killmail_event(
          victim_character_id: other_character_id,
          attackers: [
            %{
              character_id: character_id(),
              corporation_id: corporation_id(),
              ship_type_id: 588,
              final_blow: true
            }
          ]
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == false
    end

    test "matches killmail against corporation watch profile", %{user_id: user_id} do
      target_corporation_id = corporation_id()

      profile_data = %{
        name: "Corp Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :corporation_watch, corporation_ids: [target_corporation_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      killmail_event =
        build_killmail_event(
          victim_character_id: character_id(),
          victim_corporation_id: target_corporation_id,
          victim_ship_type_id: 587
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == true
    end

    test "matches killmail against system watch profile", %{user_id: user_id} do
      target_system_id = 30_000_142

      profile_data = %{
        name: "System Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :system_watch, system_ids: [target_system_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      killmail_event =
        build_killmail_event(
          victim_character_id: character_id(),
          solar_system_id: target_system_id
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == true
      assert Enum.any?(match_result.matched_criteria, fn c -> c.type == :system end)
    end

    test "matches killmail against ship type watch profile", %{user_id: user_id} do
      target_ship_type_id = 587

      profile_data = %{
        name: "Ship Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :ship_type_watch, ship_type_ids: [target_ship_type_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      killmail_event =
        build_killmail_event(
          victim_character_id: character_id(),
          victim_ship_type_id: target_ship_type_id
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)

      assert match_result.matched == true
    end

    test "validates criteria configuration", %{user_id: _user_id} do
      valid_criteria = %{type: :character_watch, character_ids: [12345]}
      assert {:ok, :valid} = MatchingEngine.validate_criteria(valid_criteria)

      invalid_criteria = %{type: :character_watch, character_ids: []}
      assert {:error, :missing_character_ids} = MatchingEngine.validate_criteria(invalid_criteria)

      invalid_type_criteria = %{type: :unknown_type}

      assert {:error, :invalid_criteria_type} =
               MatchingEngine.validate_criteria(invalid_type_criteria)
    end

    test "tests criteria against sample data", %{user_id: _user_id} do
      criteria = %{type: :character_watch, character_ids: [12345]}

      test_data = %{
        killmail_id: 1,
        solar_system_id: 30_000_142,
        killmail_time: DateTime.utc_now(),
        victim: %{character_id: 12345, corporation_id: 1, ship_type_id: 587},
        attackers: [],
        zkb_total_value: 1_000_000
      }

      {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)

      assert result.matches == true
      assert result.execution_time_ms >= 0
    end
  end

  # =============================================================================
  # 3. Alert Generation Tests
  # =============================================================================

  describe "alert generation" do
    test "configures email notifications for a profile", %{user_id: user_id} do
      profile_data = %{
        name: "Notification Config Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # NotificationService expects string keys for channels
      notification_config = %{
        :email => %{enabled: true, email_address: "test@example.com"},
        :in_app => %{enabled: true}
      }

      {:ok, config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      assert config[:email].enabled == true
      assert config[:email].email_address == "test@example.com"
      assert config[:in_app].enabled == true
    end

    test "configures webhook notifications for a profile", %{user_id: user_id} do
      profile_data = %{
        name: "Webhook Config Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      notification_config = %{
        :webhook => %{enabled: true, webhook_url: "https://example.com/webhook"}
      }

      {:ok, config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      assert config[:webhook].enabled == true
      assert config[:webhook].webhook_url == "https://example.com/webhook"
    end

    test "rejects notification config with missing email address", %{user_id: user_id} do
      profile_data = %{
        name: "Bad Notification Config #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Email enabled but no address
      notification_config = %{
        :email => %{enabled: true}
      }

      assert {:error, {:email, :missing_email_address}} =
               SurveillanceApi.configure_notifications(profile.id, notification_config)
    end

    test "rejects notification config with missing webhook URL", %{user_id: user_id} do
      profile_data = %{
        name: "Bad Webhook Config #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Webhook enabled but no URL
      notification_config = %{
        :webhook => %{enabled: true}
      }

      assert {:error, {:webhook, :missing_webhook_url}} =
               SurveillanceApi.configure_notifications(profile.id, notification_config)
    end

    test "tests notification delivery for a profile", %{user_id: user_id} do
      profile_data = %{
        name: "Test Delivery Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Configure in-app notifications (doesn't require external service)
      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      # Test notification delivery
      {:ok, test_results} = SurveillanceApi.test_notification_delivery(profile.id)

      assert is_list(test_results)
    end

    test "retrieves notification history for a profile", %{user_id: user_id} do
      profile_data = %{
        name: "History Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      {:ok, history} = SurveillanceApi.get_notification_history(profile.id)

      assert is_list(history)
    end

    test "dispatches alert notification through NotificationService", %{user_id: user_id} do
      profile_data = %{
        name: "Dispatch Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Configure in-app notifications with string keys
      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      # Create an alert
      alert = %{
        id: "test-alert-#{System.unique_integer([:positive])}",
        profile_id: profile.id,
        priority: 2,
        alert_type: :target_killed,
        confidence_score: 0.95,
        matched_criteria: [%{type: :character, character_id: 12345}],
        created_at: DateTime.utc_now()
      }

      # Dispatch the alert
      {:ok, dispatch_result} = NotificationService.dispatch_alert_notification(alert)

      assert dispatch_result.profile_id == profile.id
      assert dispatch_result.alert_id == alert.id
      assert dispatch_result.notifications_sent >= 0
    end

    test "retrieves notification metrics", %{user_id: _user_id} do
      {:ok, metrics} = NotificationService.get_notification_metrics(:last_24h)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :time_range)
      assert Map.has_key?(metrics, :total_notifications)
    end
  end

  # =============================================================================
  # 4. Real-time Updates Tests
  # =============================================================================

  describe "real-time updates" do
    test "receives PubSub notification when in-app alert is delivered", %{user_id: user_id} do
      profile_data = %{
        name: "PubSub Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      # Configure in-app notifications using string keys
      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      # Create and dispatch an alert
      alert = %{
        id: "pubsub-test-alert-#{System.unique_integer([:positive])}",
        profile_id: profile.id,
        priority: 1,
        alert_type: :target_active,
        confidence_score: 0.99,
        matched_criteria: [%{type: :character, character_id: 12345}],
        created_at: DateTime.utc_now()
      }

      {:ok, _dispatch_result} = NotificationService.dispatch_alert_notification(alert)

      # Check for PubSub message (with timeout)
      assert_receive {:surveillance_alert, notification_data}, 1000

      assert notification_data.profile_id == profile.id
      assert notification_data.alert_type == :target_active
    end

    test "broadcasts alert to surveillance:alerts topic", %{user_id: user_id} do
      # Subscribe to specific topic
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:alerts")

      profile_data = %{
        name: "Broadcast Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [12345]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)

      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _config} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      alert = %{
        id: "broadcast-test-#{System.unique_integer([:positive])}",
        profile_id: profile.id,
        priority: 2,
        alert_type: :location_activity,
        confidence_score: 0.85,
        matched_criteria: [%{type: :system, system_id: 30_000_142}],
        created_at: DateTime.utc_now()
      }

      {:ok, _} = NotificationService.dispatch_alert_notification(alert)

      # Should receive the broadcast
      assert_receive {:surveillance_alert, _data}, 1000
    end

    test "processes killmail through matching engine asynchronously", %{user_id: user_id} do
      target_character_id = character_id()

      profile_data = %{
        name: "Async Process Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      # Configure in-app notifications with string keys
      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      # Create killmail with target character
      killmail_data = %{
        killmail_id: System.unique_integer([:positive]),
        solar_system_id: 30_000_142,
        killmail_time: DateTime.utc_now(),
        victim: %{
          character_id: target_character_id,
          corporation_id: corporation_id(),
          alliance_id: nil,
          ship_type_id: 587
        },
        attackers: [
          %{
            character_id: character_id(),
            corporation_id: corporation_id(),
            alliance_id: nil,
            ship_type_id: 588,
            final_blow: true
          }
        ],
        zkb_total_value: 50_000_000
      }

      # Process killmail asynchronously
      :ok = MatchingEngine.process_killmail(killmail_data)

      # Give the GenServer time to process
      Process.sleep(100)

      # Verify metrics were updated
      metrics = MatchingEngine.get_metrics()
      assert is_map(metrics)
      assert metrics.processed_killmails >= 1
    end

    test "force match all profiles returns results", %{user_id: user_id} do
      target_character_id = character_id()

      profile_data = %{
        name: "Force Match Test #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      killmail_data = %{
        killmail_id: System.unique_integer([:positive]),
        solar_system_id: 30_000_142,
        killmail_time: DateTime.utc_now(),
        victim: %{
          character_id: target_character_id,
          corporation_id: corporation_id(),
          alliance_id: nil,
          ship_type_id: 587
        },
        attackers: [],
        zkb_total_value: 10_000_000
      }

      {:ok, matches} = MatchingEngine.force_match_all_profiles(killmail_data)

      assert is_list(matches)
      # Should have at least one match result (either match or no_match)
      matching_results =
        Enum.filter(matches, fn
          {:match, _} -> true
          _ -> false
        end)

      assert length(matching_results) >= 1
    end

    test "get_recent_matches returns result", %{user_id: _user_id} do
      # get_recent_matches may return :not_found when cache is empty
      result = MatchingEngine.get_recent_matches(limit: 10)

      # Should return {:ok, list} or {:error, :not_found}
      assert match?({:ok, _}, result) or match?({:error, :not_found}, result)
    end

    test "get cache stats returns performance metrics", %{user_id: _user_id} do
      {:ok, cache_stats} = MatchingEngine.get_cache_stats()

      assert Map.has_key?(cache_stats, :hit_rate)
      assert Map.has_key?(cache_stats, :cache_size)
      assert cache_stats.hit_rate >= 0.0 and cache_stats.hit_rate <= 1.0
    end

    test "matching engine metrics track processed killmails", %{user_id: _user_id} do
      metrics = MatchingEngine.get_metrics()

      assert Map.has_key?(metrics, :processed_killmails)
      assert Map.has_key?(metrics, :total_matches)
      assert Map.has_key?(metrics, :active_profiles)
      assert Map.has_key?(metrics, :average_processing_time_ms)
    end
  end

  # =============================================================================
  # 5. End-to-End Flow Tests
  # =============================================================================

  describe "end-to-end surveillance flow" do
    test "complete flow: create profile, match killmail, receive alert", %{user_id: user_id} do
      target_character_id = character_id()

      # Step 1: Create and configure a profile
      profile_data = %{
        name: "E2E Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, profile} = SurveillanceApi.enable_profile(profile.id)

      # Configure notifications using string keys
      notification_config = %{
        :in_app => %{enabled: true}
      }

      {:ok, _} = SurveillanceApi.configure_notifications(profile.id, notification_config)

      # Step 2: Create a killmail that matches the profile
      killmail_event =
        build_killmail_event(
          victim_character_id: target_character_id,
          victim_corporation_id: corporation_id(),
          victim_ship_type_id: 587,
          solar_system_id: 30_000_142
        )

      # Step 3: Verify the killmail matches
      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)
      assert match_result.matched == true

      # Step 4: Create and dispatch alert based on match
      alert = %{
        id: "e2e-alert-#{System.unique_integer([:positive])}",
        profile_id: profile.id,
        priority: 1,
        alert_type: :target_killed,
        confidence_score: match_result.match_confidence,
        matched_criteria: match_result.matched_criteria,
        created_at: DateTime.utc_now()
      }

      {:ok, dispatch_result} = NotificationService.dispatch_alert_notification(alert)
      assert dispatch_result.notifications_sent >= 0

      # Step 5: Verify PubSub notification received
      assert_receive {:surveillance_alert, notification_data}, 1000
      assert notification_data.profile_id == profile.id
    end

    test "complex criteria with multiple watch conditions", %{user_id: user_id} do
      target_character_id = character_id()
      target_system_id = 30_000_142

      # Create a custom criteria profile with multiple conditions
      profile_data = %{
        name: "Complex Criteria Test #{System.unique_integer([:positive])}",
        criteria: %{
          type: :custom_criteria,
          logic_operator: :and,
          conditions: [
            %{type: :character_watch, character_ids: [target_character_id]},
            %{type: :system_watch, system_ids: [target_system_id]}
          ]
        },
        user_id: user_id
      }

      {:ok, profile} = SurveillanceApi.create_profile(profile_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile.id)

      # Killmail that matches BOTH conditions
      killmail_event =
        build_killmail_event(
          victim_character_id: target_character_id,
          solar_system_id: target_system_id,
          victim_ship_type_id: 587
        )

      {:ok, match_result} = MatchingEngine.match_killmail_against_profile(killmail_event, profile)
      assert match_result.matched == true

      # Killmail that only matches one condition should not match with AND logic
      killmail_partial =
        build_killmail_event(
          victim_character_id: target_character_id,
          solar_system_id: 30_002_187,
          victim_ship_type_id: 587
        )

      {:ok, partial_result} =
        MatchingEngine.match_killmail_against_profile(killmail_partial, profile)

      assert partial_result.matched == false
    end

    test "multiple profiles receive matching alerts", %{user_id: user_id} do
      target_character_id = character_id()

      # Create two profiles watching the same character
      profile1_data = %{
        name: "Multi Profile Test 1 #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      profile2_data = %{
        name: "Multi Profile Test 2 #{System.unique_integer([:positive])}",
        criteria: %{type: :character_watch, character_ids: [target_character_id]},
        user_id: user_id
      }

      {:ok, profile1} = SurveillanceApi.create_profile(profile1_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile1.id)

      {:ok, profile2} = SurveillanceApi.create_profile(profile2_data)
      {:ok, _} = SurveillanceApi.enable_profile(profile2.id)

      # Create killmail with target character
      killmail_event =
        build_killmail_event(
          victim_character_id: target_character_id,
          victim_ship_type_id: 587
        )

      # Both profiles should match
      {:ok, match1} = MatchingEngine.match_killmail_against_profile(killmail_event, profile1)
      {:ok, match2} = MatchingEngine.match_killmail_against_profile(killmail_event, profile2)

      assert match1.matched == true
      assert match2.matched == true
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp build_killmail_event(opts) do
    default_victim_char = character_id()
    default_victim_corp = corporation_id()

    victim = %{
      character_id: Keyword.get(opts, :victim_character_id, default_victim_char),
      corporation_id: Keyword.get(opts, :victim_corporation_id, default_victim_corp),
      alliance_id: Keyword.get(opts, :victim_alliance_id, nil),
      ship_type_id: Keyword.get(opts, :victim_ship_type_id, 587)
    }

    default_attackers = [
      %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: nil,
        ship_type_id: 588,
        final_blow: true
      }
    ]

    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: Keyword.get(opts, :solar_system_id, 30_000_142),
      killmail_time: Keyword.get(opts, :killmail_time, DateTime.utc_now()),
      victim: victim,
      attackers: Keyword.get(opts, :attackers, default_attackers),
      zkb_total_value: Keyword.get(opts, :total_value, 50_000_000)
    }
  end
end
