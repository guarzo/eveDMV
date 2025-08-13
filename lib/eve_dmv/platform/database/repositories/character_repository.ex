defmodule EveDmv.Platform.Database.Repositories.CharacterRepository do
  @moduledoc """
  Repository for character data access using Ash Framework.
  Provides unified access to character-related data.
  """

  use EveDmv.Core.Contracts.RepositoryBehaviour, resource: EveDmv.Eve.Character

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Eve.Character
  require Logger

  @doc """
  Get or create a character
  """
  def get_or_create_character(character_id, attrs \\ %{}) do
    case get(character_id) do
      {:ok, character} ->
        {:ok, character}

      {:error, _} ->
        attrs = Map.put(attrs, :character_id, character_id)
        create(attrs)
    end
  end

  @doc """
  Search characters by name pattern
  """
  def search_by_name(name_pattern, opts \\ []) do
    limit_count = Keyword.get(opts, :limit, 50)

    Character
    |> new()
    |> filter(ilike(name, ^"%#{name_pattern}%"))
    |> sort(name: :asc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Get characters by corporation
  """
  def get_by_corporation(corp_id, opts \\ []) do
    limit_count = Keyword.get(opts, :limit, 100)

    Character
    |> new()
    |> filter(corporation_id == ^corp_id)
    |> sort(name: :asc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Get characters by alliance
  """
  def get_by_alliance(alliance_id, opts \\ []) do
    limit_count = Keyword.get(opts, :limit, 500)

    Character
    |> new()
    |> filter(alliance_id == ^alliance_id)
    |> sort(name: :asc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Update character corporation/alliance
  """
  def update_affiliation(character_id, corp_id, alliance_id \\ nil) do
    with {:ok, character} <- get(character_id) do
      update(character, %{
        corporation_id: corp_id,
        alliance_id: alliance_id,
        last_updated: DateTime.utc_now()
      })
    end
  end

  @doc """
  Bulk update character data
  """
  def bulk_update_characters(updates) when is_list(updates) do
    # Transform updates to Ash format
    changesets =
      Enum.map(updates, fn {character_id, attrs} ->
        %{character_id: character_id}
        |> Map.merge(attrs)
        |> Map.put(:last_updated, DateTime.utc_now())
      end)

    # Since bulk_update doesn't exist, we'll use bulk_create with upsert
    case Ash.bulk_create(changesets, Character, :create,
           upsert?: true,
           upsert_identity: :unique_character_id,
           return_errors?: true,
           batch_size: 100,
           domain: Api
         ) do
      %Ash.BulkResult{status: :success} = result ->
        {:ok, result}

      %Ash.BulkResult{status: :partial_success} = result ->
        {:partial, result}

      %Ash.BulkResult{errors: errors} ->
        {:error, errors}
    end
  end

  @doc """
  Get recently active characters
  """
  def get_recently_active(opts \\ []) do
    days_back = Keyword.get(opts, :days_back, 7)
    limit_count = Keyword.get(opts, :limit, 100)

    cutoff_date = DateTime.add(DateTime.utc_now(), -(days_back * 24 * 60 * 60), :second)

    Character
    |> new()
    |> filter(last_seen >= ^cutoff_date)
    |> sort(last_seen: :desc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Check if character exists
  """
  def character_exists?(character_id) do
    exists?(filters: [character_id: character_id])
  end

  @doc """
  Get character statistics
  """
  def get_character_stats(character_id) do
    with {:ok, character} <- get(character_id) do
      {:ok,
       %{
         character_id: character.character_id,
         name: character.name,
         corporation_id: character.corporation_id,
         alliance_id: character.alliance_id,
         last_seen: character.last_seen,
         created_at: character.inserted_at,
         days_tracked: calculate_days_tracked(character)
       }}
    end
  end

  defp calculate_days_tracked(character) do
    if character.inserted_at do
      DateTime.diff(DateTime.utc_now(), character.inserted_at, :day)
    else
      0
    end
  end
end
