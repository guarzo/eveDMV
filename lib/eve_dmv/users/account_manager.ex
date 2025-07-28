defmodule EveDmv.Users.AccountManager do
  @moduledoc """
  Service module for managing user accounts and multi-character support.

  Handles account creation, character linking, character switching,
  and account-level operations.
  """

  alias EveDmv.Users.Account
  alias EveDmv.Users.User
  alias EveDmv.Api
  require Logger
  require Ash.Query

  @doc """
  Creates or finds an account for a user during authentication.

  If the user doesn't have an account, creates one and sets them as primary character.
  If they already have an account, just returns it.
  """
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
  def link_character_to_account(new_user, account_id) do
    account = get_account!(account_id)

    with {:ok, linked_user} <- link_user_to_account(new_user, account) do
      {:ok, account, linked_user}
    end
  end

  @doc """
  Switches the active character for an account.

  Updates the last character switch timestamp and optionally updates
  the primary character if requested.
  """
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

      case Ash.update(account, update_params, domain: Api) do
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
  def get_account_characters(account_id) do
    User
    |> Ash.Query.new()
    |> Ash.Query.filter(account_id: account_id)
    |> Ash.read!(domain: Api)
  end

  @doc """
  Gets the primary character for an account.
  """
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

      # Check if we've reached a character limit (optional)
      length(get_account_characters(account.id)) >= max_characters_per_account() ->
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
  def merge_accounts(source_account_id, target_account_id) do
    source_account = get_account!(source_account_id)
    target_account = get_account!(target_account_id)

    # Get all characters from source account
    source_characters = get_account_characters(source_account_id)

    # Move each character to target account
    Enum.each(source_characters, fn character ->
      Ash.update!(character, %{account_id: target_account_id}, domain: Api)
    end)

    # If source account's primary character isn't set in target, use it
    if is_nil(target_account.primary_character_id) && source_account.primary_character_id do
      Ash.update!(target_account, %{primary_character_id: source_account.primary_character_id},
        domain: Api
      )
    end

    # Delete the source account
    Ash.destroy!(source_account, domain: Api)

    {:ok, target_account}
  end

  @doc """
  Updates account activity timestamps.
  """
  def update_account_activity(account_id) do
    account = get_account!(account_id)

    Ash.update!(account, %{last_login_at: DateTime.utc_now()}, domain: Api)
  end

  # Private functions

  defp create_account(user) do
    Account
    |> Ash.Changeset.for_create(:create, %{
      primary_character_id: user.id,
      last_login_at: DateTime.utc_now(),
      is_admin: user.is_admin || false
    })
    |> Ash.create(domain: Api)
  end

  defp link_user_to_account(user, account) do
    user
    |> Ash.Changeset.for_update(:update, %{account_id: account.id})
    |> Ash.update(domain: Api)
  end

  defp get_account!(account_id) do
    Account
    |> Ash.get!(account_id, domain: Api)
  end

  defp get_user_by_id!(user_id) do
    User
    |> Ash.get!(user_id, domain: Api)
  end

  defp max_characters_per_account do
    # Could be made configurable
    Application.get_env(:eve_dmv, :max_characters_per_account, 10)
  end
end
