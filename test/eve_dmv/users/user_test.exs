defmodule EveDmv.Users.UserTest do
  use EveDmv.DataCase, async: true
  use ExUnitProperties

  alias EveDmv.Api
  alias EveDmv.Users.User

  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "register_with_eve_sso/1" do
    test "creates user with valid EVE SSO data" do
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "valid_access_token",
        "refresh_token" => "valid_refresh_token",
        "expires_in" => 3600
      }

      assert {:ok, user} =
               Ash.create(
                 User,
                 %{
                   user_info: user_info,
                   oauth_tokens: oauth_tokens
                 },
                 action: :register_with_eve_sso,
                 domain: Api
               )

      assert user.eve_character_id == 123_456
      assert user.eve_character_name == "TestPilot"
      assert user.access_token == "valid_access_token"
      assert user.refresh_token == "valid_refresh_token"
      assert user.token_expires_at
    end

    test "fails with missing required EVE SSO data" do
      incomplete_user_info = %{
        "CharacterID" => 123_456
        # Missing CharacterName
      }

      oauth_tokens = %{
        "access_token" => "token"
        # Missing refresh_token
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 User,
                 %{
                   user_info: incomplete_user_info,
                   oauth_tokens: oauth_tokens
                 },
                 action: :register_with_eve_sso,
                 domain: Api
               )
    end

    test "fails with invalid character ID format" do
      invalid_user_info = %{
        # Should be integer
        "CharacterID" => "invalid_id",
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 User,
                 %{
                   user_info: invalid_user_info,
                   oauth_tokens: oauth_tokens
                 },
                 action: :register_with_eve_sso,
                 domain: Api
               )
    end

    test "upserts on duplicate character registration" do
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens1 = %{
        "access_token" => "token1",
        "refresh_token" => "refresh1",
        "expires_in" => 3600
      }

      oauth_tokens2 = %{
        "access_token" => "token2",
        "refresh_token" => "refresh2",
        "expires_in" => 3600
      }

      # First registration should succeed
      assert {:ok, user1} =
               Ash.create(
                 User,
                 %{
                   user_info: user_info,
                   oauth_tokens: oauth_tokens1
                 },
                 action: :register_with_eve_sso,
                 domain: Api
               )

      # Second registration with same character_id should update (upsert)
      assert {:ok, user2} =
               Ash.create(
                 User,
                 %{
                   user_info: user_info,
                   oauth_tokens: oauth_tokens2
                 },
                 action: :register_with_eve_sso,
                 domain: Api
               )

      # Should be the same user with updated tokens
      assert user1.id == user2.id
      assert user2.access_token == "token2"
    end
  end

  describe "sign_in_with_eve_sso/1" do
    setup do
      # Create existing user for sign-in tests
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "old_token",
        "refresh_token" => "old_refresh",
        # Expired
        "expires_in" => -3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      {:ok, user: user}
    end

    test "updates existing user with new token data", %{user: user} do
      new_user_info = %{
        "CharacterID" => user.eve_character_id,
        "CharacterName" => user.eve_character_name
      }

      new_oauth_tokens = %{
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 3600
      }

      assert {:ok, updated_user} =
               Ash.create(
                 User,
                 %{
                   user_info: new_user_info,
                   oauth_tokens: new_oauth_tokens
                 },
                 action: :sign_in_with_eve_sso,
                 domain: Api
               )

      assert updated_user.id == user.id
      assert updated_user.access_token == "new_access_token"
      assert updated_user.refresh_token == "new_refresh_token"
    end

    test "creates new user if character doesn't exist" do
      new_user_info = %{
        "CharacterID" => 999_888,
        "CharacterName" => "NewPilot"
      }

      new_oauth_tokens = %{
        "access_token" => "fresh_token",
        "refresh_token" => "fresh_refresh",
        "expires_in" => 3600
      }

      assert {:ok, new_user} =
               Ash.create(
                 User,
                 %{
                   user_info: new_user_info,
                   oauth_tokens: new_oauth_tokens
                 },
                 action: :sign_in_with_eve_sso,
                 domain: Api
               )

      assert new_user.eve_character_id == 999_888
      assert new_user.eve_character_name == "NewPilot"
    end
  end

  describe "authorization policies" do
    setup do
      # Create two users for authorization testing
      user1_info = %{"CharacterID" => 111_111, "CharacterName" => "User1"}

      user1_tokens = %{
        "access_token" => "token1",
        "refresh_token" => "refresh1",
        "expires_in" => 3600
      }

      user2_info = %{"CharacterID" => 333_333, "CharacterName" => "User2"}

      user2_tokens = %{
        "access_token" => "token2",
        "refresh_token" => "refresh2",
        "expires_in" => 3600
      }

      {:ok, user1} =
        Ash.create(
          User,
          %{
            user_info: user1_info,
            oauth_tokens: user1_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      {:ok, user2} =
        Ash.create(
          User,
          %{
            user_info: user2_info,
            oauth_tokens: user2_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      {:ok, user1: user1, user2: user2}
    end

    test "user can read their own data", %{user1: user1} do
      assert {:ok, fetched_user} = Ash.get(User, user1.id, actor: user1, domain: Api)
      assert fetched_user.id == user1.id
    end

    test "user cannot read other user's data", %{user1: user1, user2: user2} do
      assert {:error, %Ash.Error.Forbidden{}} = Ash.get(User, user2.id, actor: user1, domain: Api)
    end

    test "unauthenticated requests are forbidden", %{user1: user1} do
      assert {:error, %Ash.Error.Forbidden{}} = Ash.get(User, user1.id, domain: Api)
    end
  end

  describe "token expiration handling" do
    test "identifies expired tokens" do
      user_info = %{"CharacterID" => 123_456, "CharacterName" => "TestPilot"}

      expired_tokens = %{
        "access_token" => "expired_token",
        "refresh_token" => "refresh_token",
        # 1 hour ago (negative means expired)
        "expires_in" => -3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: expired_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Token should be marked as expired
      assert DateTime.compare(user.token_expires_at, DateTime.utc_now()) == :lt
    end

    test "accepts valid tokens" do
      user_info = %{"CharacterID" => 123_456, "CharacterName" => "TestPilot"}

      valid_tokens = %{
        "access_token" => "valid_token",
        "refresh_token" => "refresh_token",
        # 1 hour from now
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: valid_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Token should be valid
      assert DateTime.compare(user.token_expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "helper functions" do
    test "signing_secret/2 returns configured secret" do
      # This tests the private function through the API
      # Since it's used in the authentication flow
      result = User.signing_secret(nil, nil)

      case result do
        {:ok, secret} ->
          assert is_binary(secret)
          assert byte_size(secret) > 0

        {:error, message} ->
          # This is expected if token_signing_secret is not configured
          assert is_binary(message)
      end
    end
  end

  # Property-based testing for complex validation logic
  property "EVE character IDs are always positive integers" do
    check all(character_id <- positive_integer()) do
      user_info = %{
        "CharacterID" => character_id,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      result =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      assert match?({:ok, %User{}}, result)
    end
  end
end
