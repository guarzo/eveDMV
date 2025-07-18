defmodule EveDmv.Admin do
  @moduledoc """
  Administrative functions for user management.

  Provides utilities for:
  - Promoting users to admin status
  - Listing admin users
  - Managing admin privileges
  """

  alias EveDmv.Api
  alias EveDmv.Users.User

  @doc """
  Promote a user to admin status by character ID.

  ## Examples

      iex> EveDmv.Admin.promote_user_to_admin(123456789)
      {:ok, %User{is_admin: true}}
      
      iex> EveDmv.Admin.promote_user_to_admin(999999999)
      {:error, :user_not_found}
  """
  def promote_user_to_admin(character_id) when is_integer(character_id) do
    case Ash.read_one(User, domain: Api, filter: [eve_character_id: character_id]) do
      {:ok, user} -> update_user_admin_status(user, true)
      {:error, _} -> {:error, :user_not_found}
      nil -> {:error, :user_not_found}
    end
  end

  def promote_user_to_admin(character_name) when is_binary(character_name) do
    case Ash.read_one(User, domain: Api, filter: [eve_character_name: character_name]) do
      {:ok, user} -> update_user_admin_status(user, true)
      {:error, _} -> {:error, :user_not_found}
      nil -> {:error, :user_not_found}
    end
  end

  @doc """
  Remove admin status from a user.
  """
  def demote_admin(character_id) when is_integer(character_id) do
    case Ash.read_one(User, domain: Api, filter: [eve_character_id: character_id]) do
      {:ok, user} -> update_user_admin_status(user, false)
      {:error, _} -> {:error, :user_not_found}
      nil -> {:error, :user_not_found}
    end
  end

  @doc """
  List all admin users.
  """
  def list_admins do
    Ash.read!(User, domain: Api, filter: [is_admin: true])
  end

  @doc """
  Check if a user is an admin by character ID.
  """
  def is_admin?(character_id) when is_integer(character_id) do
    case Ash.read_one(User, domain: Api, filter: [eve_character_id: character_id]) do
      {:ok, %User{is_admin: true}} -> true
      _ -> false
    end
  end

  def is_admin?(character_name) when is_binary(character_name) do
    case Ash.read_one(User, domain: Api, filter: [eve_character_name: character_name]) do
      {:ok, %User{is_admin: true}} -> true
      _ -> false
    end
  end

  @doc """
  Bootstrap the first admin user. Use this in production console to create
  the initial admin user.

  ## Example

      # In IEx console:
      EveDmv.Admin.bootstrap_first_admin("Your Character Name")
      
  ## Environment Variable Bootstrap (Recommended)

  For production deployment, use environment variables instead:

      # In production environment:
      ADMIN_BOOTSTRAP_CHARACTERS="Your Character Name,Another Admin"
      ADMIN_BOOTSTRAP_CHARACTER_IDS="123456789,987654321"
      
  Admin users will be automatically promoted during application startup.
  """
  def bootstrap_first_admin(character_name) when is_binary(character_name) do
    admin_count = Ash.count!(User, domain: Api, filter: [is_admin: true])

    if admin_count == 0 do
      case promote_user_to_admin(character_name) do
        {:ok, user} ->
          IO.puts("✅ Successfully promoted #{user.eve_character_name} to admin!")
          {:ok, user}

        {:error, :user_not_found} ->
          IO.puts(
            "❌ User '#{character_name}' not found. Make sure they have logged in at least once."
          )

          {:error, :user_not_found}

        {:error, reason} ->
          IO.puts("❌ Failed to promote user: #{inspect(reason)}")
          {:error, reason}
      end
    else
      IO.puts("⚠️  Admin users already exist. Use promote_user_to_admin/1 instead.")
      {:error, :admins_already_exist}
    end
  end

  # Private helper function to update user admin status
  defp update_user_admin_status(user, admin_status) do
    case Ash.update(user, %{is_admin: admin_status}, domain: Api) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, reason} -> {:error, reason}
    end
  end
end
