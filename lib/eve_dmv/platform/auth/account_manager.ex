defmodule EveDmv.Users.AccountManager do
  @moduledoc """
  Service module for managing user accounts and multi-character support.

  Handles account creation, character linking, character switching,
  and account-level operations.
  """

  alias EveDmv.Api
  alias EveDmv.Users.Account
  alias EveDmv.Users.User
  require Logger
  require Ash.Query

  @type account :: Account.t()
  @type user :: User.t()
  @type account_id :: integer() | String.t()
  @type user_id :: integer() | String.t()
  @type error :: {:error, term()}

  @doc """
  Creates or finds an account for a user during authentication.

  If the user doesn't have an account, creates one and sets them as primary character.
  If they already have an account, just returns it.
  """
  @spec ensure_user_account(user()) :: {:ok, account()} | error()
  def ensure_user_account(user) do
    case user.account_id do
      nil ->
        create_account_for_user(user)

      account_id ->
        {:ok, get_account!(account_id)}
    end
  end

  @doc """
  Creates a new account for a user and sets them as the primary character.
  """
  @spec create_account_for_user(user()) :: {:ok, account()} | error()
  def create_account_for_user(user) do
    with {:ok, account} <- create_account(user),
         {:ok, _updated_user} <- link_user_to_account(user, account) do
      {:ok, account}
    end
  end

  @doc """
  Links an additional character to an existing account.

  This is used when a user authenticates with a different EVE character
  but wants to link it to their existing account.
  """
  @spec link_character_to_account(user(), account_id()) :: {:ok, account(), user()} | error()
  def link_character_to_account(new_user, account_id) do
    account = get_account!(account_id)

    with {:ok, linked_user} <- link_user_to_account(new_user, account) do
      {:ok, account, linked_user}
    end
  end

  @doc """
  Re-links a character from one account to another.

  This is used when a user wants to add a character that was previously
  linked to a different account (e.g., from testing or accidental separate logins).
  The old account may become empty if this was its only character.
  """
  @spec relink_character_to_account(user(), account_id()) :: {:ok, account(), user()} | error()
  def relink_character_to_account(user, new_account_id) do
    old_account_id = user.account_id
    new_account = get_account!(new_account_id)

    Logger.info(
      "Re-linking character #{user.eve_character_name} from account #{old_account_id} to #{new_account_id}"
    )

    # Update the user's account_id to point to the new account
    with {:ok, updated_user} <- link_user_to_account(user, new_account) do
      # Clean up: if old account has no more characters, we could delete it
      # For now, just log this situation
      old_char_count = get_account_character_count(old_account_id)

      if old_char_count == 0 do
        Logger.info("Old account #{old_account_id} now has no characters - consider cleanup")
      end

      {:ok, new_account, updated_user}
    end
  end

  @doc """
  Gets an account by its ID. Raises if not found.
  """
  @spec get_account_by_id!(account_id()) :: account() | no_return()
  def get_account_by_id!(account_id) do
    get_account!(account_id)
  end

  @doc """
  Switches the active character for an account.

  Updates the last character switch timestamp and optionally updates
  the primary character if requested.
  """
  @spec switch_character(account_id(), user_id(), boolean()) :: {:ok, account(), user()} | error()
  def switch_character(account_id, character_id, make_primary \\ false) do
    account = get_account!(account_id)
    character = get_user_by_id!(character_id)

    # Verify the character belongs to this account
    if character.account_id != account.id do
      {:error, :character_not_in_account}
    else
      update_params = %{last_character_switch_at: DateTime.utc_now()}

      update_params =
        if make_primary do
          Map.put(update_params, :primary_character_id, character_id)
        else
          update_params
        end

      case Ash.update(account, update_params, domain: EveDmv.Api) do
        {:ok, updated_account} ->
          {:ok, updated_account, character}

        error ->
          error
      end
    end
  end

  @doc """
  Gets all characters associated with an account.
  """
  @spec get_account_characters(account_id()) :: [user()]
  def get_account_characters(account_id) do
    User
    |> Ash.Query.new()
    |> Ash.Query.filter(account_id: account_id)
    |> Ash.read!(domain: EveDmv.Api)
  end

  @doc """
  Gets the primary character for an account.
  """
  @spec get_primary_character(account()) :: user() | nil
  def get_primary_character(account) do
    case account.primary_character_id do
      nil -> nil
      character_id -> get_user_by_id!(character_id)
    end
  end

  @doc """
  Checks if a character can be linked to an account.

  Returns :ok if linkable, or an error tuple with the reason.
  """
  def validate_character_linkable(character, account) do
    cond do
      # Character already linked to a different account
      character.account_id && character.account_id != account.id ->
        {:error, :already_linked_to_different_account}

      # Character is already linked to this account
      character.account_id == account.id ->
        {:error, :already_linked_to_this_account}

      # Check if we've reached a character limit (use count query instead of loading all)
      get_account_character_count(account.id) >= max_characters_per_account() ->
        {:error, :character_limit_reached}

      true ->
        :ok
    end
  end

  @doc """
  Merges two accounts when a user accidentally creates multiple accounts.

  Moves all characters from the source account to the target account,
  then deletes the source account.
  """
  @spec merge_accounts(account_id(), account_id()) :: {:ok, account()} | error()
  def merge_accounts(source_account_id, target_account_id) do
    source_account = get_account!(source_account_id)
    target_account = get_account!(target_account_id)

    # Bulk update all characters from source account to target account
    User
    |> Ash.Query.new()
    |> Ash.Query.filter(account_id: source_account_id)
    |> Ash.bulk_update!(:update, %{account_id: target_account_id}, domain: EveDmv.Api)

    # If source account's primary character isn't set in target, use it
    if is_nil(target_account.primary_character_id) && source_account.primary_character_id do
      attrs = %{primary_character_id: source_account.primary_character_id}

      case Ash.update(target_account, attrs, domain: EveDmv.Api) do
        {:ok, _updated} -> :ok
        {:error, reason} -> raise "Failed to update target account: #{inspect(reason)}"
      end
    end

    # Delete the source account
    case Ash.destroy(source_account, domain: EveDmv.Api) do
      :ok -> :ok
      {:error, reason} -> raise "Destroy failed: #{inspect(reason)}"
    end

    {:ok, target_account}
  end

  @doc """
  Updates account activity timestamps.
  """
  @dialyzer {:nowarn_function, update_account_activity: 1}
  @spec update_account_activity(account_id()) :: {:ok, account()} | {:error, term()}
  def update_account_activity(account_id) do
    account = get_account!(account_id)

    Ash.update(account, %{}, action: :update_last_login, domain: EveDmv.Api)
  end

  # Private functions

  @spec create_account(user()) :: {:ok, account()} | error()
  defp create_account(user) do
    Account
    |> Ash.Changeset.for_create(:create, %{
      primary_character_id: user.id,
      is_admin: user.is_admin || false
    })
    |> Ash.create(domain: Api)
  end

  @spec link_user_to_account(user(), account()) :: {:ok, user()} | error()
  defp link_user_to_account(user, account) do
    user
    |> Ash.Changeset.for_update(:link_to_account, %{account_id: account.id})
    |> Ash.update(domain: EveDmv.Api)
  end

  @spec get_account!(account_id()) :: account() | no_return()
  defp get_account!(account_id) do
    Account
    |> Ash.get(account_id, domain: Api)
    |> case do
      {:ok, account} -> account
      _ -> raise "Account not found"
    end
  end

  @spec get_user_by_id!(user_id()) :: user() | no_return()
  defp get_user_by_id!(user_id) do
    User
    |> Ash.get(user_id, domain: Api)
    |> case do
      {:ok, user} -> user
      _ -> raise "User not found"
    end
  end

  @spec max_characters_per_account() :: integer()
  defp max_characters_per_account do
    # Could be made configurable
    Application.get_env(:eve_dmv, :max_characters_per_account, 10)
  end

  @spec get_account_character_count(account_id()) :: integer()
  defp get_account_character_count(account_id) do
    # Use count query instead of loading all characters
    User
    |> Ash.Query.new()
    |> Ash.Query.filter(account_id: account_id)
    |> Ash.count!(domain: EveDmv.Api)
  end
end
