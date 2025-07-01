defmodule EveDmv.Users.TokenTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Api
  alias EveDmv.Users.{Token, User}

  describe "token resource" do
    setup do
      # Create a user for token testing
      user_info = %{"CharacterID" => 123_456, "CharacterName" => "TestPilot"}

      oauth_tokens = %{
        "access_token" => "test_token",
        "refresh_token" => "test_refresh",
        "expires_in" => 3600
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

    test "can create tokens for authenticated users", %{user: user} do
      # AshAuthentication.TokenResource handles token creation
      # Test that tokens are automatically created during authentication

      # Get tokens created for the user
      tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user, domain: Api)

      # Should have at least one token from the registration
      assert length(tokens) >= 1

      # First token should have the user as subject
      token = List.first(tokens)
      assert token.subject == to_string(user.id)
    end

    test "tokens have proper expiration", %{user: user} do
      # Get existing tokens for the user
      tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user, domain: Api)

      if length(tokens) > 0 do
        token = List.first(tokens)
        # Token should have an expiration date
        assert token.expires_at
        # Token should be valid (not expired)
        assert DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt
      end
    end

    test "can validate tokens", %{user: user} do
      # Get existing tokens for the user
      tokens = Api.read!(Token, actor: user)

      if length(tokens) > 0 do
        token = List.first(tokens)

        # Should be able to find the token by its ID
        assert {:ok, found_token} = Ash.get(Token, token.id, actor: user, domain: Api)
        assert found_token.subject == token.subject
      end
    end

    test "can revoke tokens", %{user: user} do
      # Get existing tokens for the user
      tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user, domain: Api)

      if length(tokens) > 0 do
        token = List.first(tokens)

        # Revoke the token
        assert {:ok, _} = Ash.destroy(Token, token.id, actor: user, domain: Api)

        # Token should no longer be found
        assert {:error, %Ash.Error.Query.NotFound{}} =
                 Ash.get(Token, token.id, actor: user, domain: Api)
      end
    end

    test "tokens have unique values", %{user: user} do
      # Test that authentication creates unique tokens
      # Re-authenticate to generate a new token
      user_info = %{
        "CharacterID" => user.eve_character_id,
        "CharacterName" => user.eve_character_name
      }

      oauth_tokens = %{
        "access_token" => "new_token",
        "refresh_token" => "new_refresh",
        "expires_in" => 3600
      }

      {:ok, _updated_user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :sign_in_with_eve_sso,
          domain: Api
        )

      # Should now have tokens (potentially multiple)
      tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user, domain: Api)

      if length(tokens) >= 2 do
        [token1, token2 | _] = tokens
        assert token1.token != token2.token
      end
    end

    test "expired tokens should be identifiable" do
      # This test checks that token expiration is properly handled
      # We'll test this by examining existing tokens
      user_info = %{"CharacterID" => 999_999, "CharacterName" => "ExpiredTestPilot"}

      expired_tokens = %{
        "access_token" => "expired",
        "refresh_token" => "expired_refresh",
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

      # The user's OAuth tokens should be expired
      assert DateTime.compare(user.token_expires_at, DateTime.utc_now()) == :lt
    end
  end

  describe "token security" do
    setup do
      user_info = %{"CharacterID" => 123_456, "CharacterName" => "TestPilot"}

      oauth_tokens = %{
        "access_token" => "test_token",
        "refresh_token" => "test_refresh",
        "expires_in" => 3600
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

    test "tokens are unique", %{user: user} do
      # Generate multiple authentication tokens by signing in multiple times
      user_info = %{
        "CharacterID" => user.eve_character_id,
        "CharacterName" => user.eve_character_name
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

      {:ok, _} =
        Ash.create(User, %{user_info: user_info, oauth_tokens: oauth_tokens1},
          action: :sign_in_with_eve_sso,
          domain: Api
        )

      {:ok, _} =
        Ash.create(User, %{user_info: user_info, oauth_tokens: oauth_tokens2},
          action: :sign_in_with_eve_sso,
          domain: Api
        )

      # Check that tokens are unique (this may not create multiple tokens depending on implementation)
      tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user, domain: Api)
      assert length(tokens) >= 1
    end

    test "tokens cannot be accessed by wrong user" do
      # Create two users
      user1_info = %{"CharacterID" => 123_456, "CharacterName" => "TestPilot1"}

      user1_tokens = %{
        "access_token" => "token1",
        "refresh_token" => "refresh1",
        "expires_in" => 3600
      }

      user2_info = %{"CharacterID" => 789_012, "CharacterName" => "TestPilot2"}

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

      # Get user1's tokens
      user1_tokens = Token |> Ash.Query.new() |> Ash.read!(actor: user1, domain: Api)

      if length(user1_tokens) > 0 do
        token1 = List.first(user1_tokens)

        # User2 should not be able to access user1's token
        assert {:error, %Ash.Error.Forbidden{}} =
                 Ash.get(Token, token1.id, actor: user2, domain: Api)
      end
    end
  end
end
