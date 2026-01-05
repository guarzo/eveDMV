defmodule EveDmv.Contexts.Surveillance.ApiTest do
  @moduledoc """
  Tests for the Surveillance API module.

  Tests pure validation logic that doesn't require infrastructure.
  The Surveillance context relies on a ProfileRepository GenServer that
  is not available in the test environment, so we focus on input validation.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.Surveillance.Api

  # Helper to build valid profile data
  defp valid_profile_data(overrides) do
    Map.merge(
      %{
        name: "Test Profile #{System.unique_integer([:positive])}",
        criteria: %{type: :character, character_ids: [character_id()]},
        user_id: Enum.random(1..100_000)
      },
      overrides
    )
  end

  describe "create_profile/1 validation" do
    test "rejects profile with missing required fields" do
      incomplete_data = %{name: "Test"}

      result = Api.create_profile(incomplete_data)

      assert {:error, _reason} = result
    end

    test "rejects profile with name too short" do
      profile_data = valid_profile_data(%{name: "ab"})

      result = Api.create_profile(profile_data)

      assert {:error, :name_too_short} = result
    end

    test "rejects profile with name too long" do
      long_name = String.duplicate("a", 101)
      profile_data = valid_profile_data(%{name: long_name})

      result = Api.create_profile(profile_data)

      assert {:error, :name_too_long} = result
    end

    test "rejects profile with empty name (whitespace only)" do
      profile_data = valid_profile_data(%{name: "   "})

      result = Api.create_profile(profile_data)

      assert {:error, :name_empty} = result
    end

    test "rejects profile with non-string name" do
      profile_data = valid_profile_data(%{name: 12_345})

      result = Api.create_profile(profile_data)

      assert {:error, :invalid_name_type} = result
    end

    test "rejects profile with invalid criteria type" do
      profile_data = valid_profile_data(%{criteria: "not a map"})

      result = Api.create_profile(profile_data)

      assert {:error, :invalid_criteria_type} = result
    end

    test "rejects profile with criteria missing type field" do
      profile_data = valid_profile_data(%{criteria: %{character_ids: [123]}})

      result = Api.create_profile(profile_data)

      assert {:error, _reason} = result
    end

    test "rejects profile with invalid user_id (negative)" do
      profile_data = valid_profile_data(%{user_id: -1})

      result = Api.create_profile(profile_data)

      assert {:error, :invalid_user_id} = result
    end

    test "rejects profile with invalid user_id (zero)" do
      profile_data = valid_profile_data(%{user_id: 0})

      result = Api.create_profile(profile_data)

      assert {:error, :invalid_user_id} = result
    end

    test "rejects profile with non-integer user_id" do
      profile_data = valid_profile_data(%{user_id: "user123"})

      result = Api.create_profile(profile_data)

      assert {:error, :invalid_user_id} = result
    end
  end

  describe "validate_profile_criteria/1" do
    test "validates character_watch criteria" do
      criteria = %{type: :character_watch, character_ids: [character_id()]}

      result = Api.validate_profile_criteria(criteria)

      assert {:ok, :valid} = result
    end

    test "validates corporation_watch criteria" do
      criteria = %{type: :corporation_watch, corporation_ids: [corporation_id()]}

      result = Api.validate_profile_criteria(criteria)

      assert {:ok, :valid} = result
    end

    test "validates system_watch criteria" do
      criteria = %{type: :system_watch, system_ids: [30_000_142]}

      result = Api.validate_profile_criteria(criteria)

      assert {:ok, :valid} = result
    end

    test "rejects unknown criteria type" do
      criteria = %{type: :unknown_watch}

      result = Api.validate_profile_criteria(criteria)

      assert {:error, :invalid_criteria_type} = result
    end
  end

  describe "configure_notifications/2 validation" do
    test "rejects invalid notification types" do
      # sms is not a valid notification type
      notification_config = %{sms: %{phone: "1234567890"}}

      result = Api.configure_notifications("profile-id", notification_config)

      assert {:error, {:invalid_notification_types, [:sms]}} = result
    end

    test "rejects multiple invalid notification types" do
      notification_config = %{
        sms: %{phone: "1234567890"},
        push: %{enabled: true}
      }

      result = Api.configure_notifications("profile-id", notification_config)

      assert {:error, {:invalid_notification_types, invalid_types}} = result
      assert :sms in invalid_types
      assert :push in invalid_types
    end

    test "rejects non-map notification config" do
      result = Api.configure_notifications("profile-id", "invalid")

      assert {:error, :invalid_notification_config_type} = result
    end

    test "rejects list notification config" do
      result = Api.configure_notifications("profile-id", [:email, :webhook])

      assert {:error, :invalid_notification_config_type} = result
    end

    test "rejects nil notification config" do
      result = Api.configure_notifications("profile-id", nil)

      assert {:error, :invalid_notification_config_type} = result
    end
  end

  # Note: test_profile_criteria/2 calls get_profile first, so we can't test
  # test data validation in isolation without the ProfileRepository running.

  describe "API module exports" do
    # These tests verify the module exports the expected functions
    setup do
      Code.ensure_loaded!(Api)
      :ok
    end

    test "exports profile management functions" do
      assert function_exported?(Api, :create_profile, 1)
      assert function_exported?(Api, :update_profile, 2)
      assert function_exported?(Api, :delete_profile, 1)
      assert function_exported?(Api, :get_profile, 1)
      # list_profiles has default args, so arity 0 is also valid
      assert function_exported?(Api, :list_profiles, 0) or
               function_exported?(Api, :list_profiles, 1)

      assert function_exported?(Api, :enable_profile, 1)
      assert function_exported?(Api, :disable_profile, 1)
    end

    test "exports matching functions" do
      # get_recent_matches has default args
      assert function_exported?(Api, :get_recent_matches, 0) or
               function_exported?(Api, :get_recent_matches, 1)

      assert function_exported?(Api, :get_matches_for_profile, 1) or
               function_exported?(Api, :get_matches_for_profile, 2)

      assert function_exported?(Api, :get_match_details, 1)
      assert function_exported?(Api, :get_match_statistics, 2)
    end

    test "exports criteria functions" do
      assert function_exported?(Api, :test_profile_criteria, 2)
      assert function_exported?(Api, :validate_profile_criteria, 1)
    end

    test "exports notification functions" do
      assert function_exported?(Api, :configure_notifications, 2)

      assert function_exported?(Api, :get_notification_history, 1) or
               function_exported?(Api, :get_notification_history, 2)

      assert function_exported?(Api, :test_notification_delivery, 1)
    end
  end
end
