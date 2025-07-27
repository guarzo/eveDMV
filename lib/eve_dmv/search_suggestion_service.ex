defmodule SearchSuggestionService do
  @moduledoc """
  Service for providing search suggestions for characters, corporations, alliances, systems, and ships.

  This service queries actual database tables to provide intelligent search suggestions
  based on user input. It uses PostgreSQL's trigram indexing for fuzzy search capabilities.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Eve.{ItemType, SolarSystem}
  import Ash.Query

  @doc """
  Get character name suggestions based on a search query.

  Queries the participants table to find character names that match the search term.
  Returns unique character names with their IDs.

  ## Parameters
  - `query` - The search string
  - `opts` - Options including :limit (default: 5)

  ## Returns
  - `{:ok, suggestions}` - List of %{id: character_id, name: character_name}
  - `{:error, reason}` - Error if query fails

  ## Examples
      iex> SearchSuggestionService.get_character_suggestions("John", limit: 3)
      {:ok, [%{id: 123456, name: "John Doe"}, %{id: 789012, name: "Johnny Smith"}]}
  """
  def get_character_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    try do
      suggestions =
        Participant
        |> select([:character_id, :character_name])
        |> filter(not is_nil(character_id) and not is_nil(character_name))
        |> filter(ilike(character_name, ^"%#{query}%"))
        |> distinct([:character_id, :character_name])
        |> sort(:character_name)
        |> limit(limit)
        |> Api.read!()
        |> Enum.map(fn participant ->
          %{id: participant.character_id, name: participant.character_name}
        end)

      {:ok, suggestions}
    rescue
      error ->
        {:error, "Character search failed: #{inspect(error)}"}
    end
  end

  @doc """
  Get corporation name suggestions based on a search query.

  Queries the participants table to find corporation names that match the search term.
  Returns unique corporation names with their IDs.

  ## Parameters
  - `query` - The search string
  - `opts` - Options including :limit (default: 5)

  ## Returns
  - `{:ok, suggestions}` - List of %{id: corporation_id, name: corporation_name}
  - `{:error, reason}` - Error if query fails
  """
  def get_corporation_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    try do
      suggestions =
        Participant
        |> select([:corporation_id, :corporation_name])
        |> filter(not is_nil(corporation_id) and not is_nil(corporation_name))
        |> filter(ilike(corporation_name, ^"%#{query}%"))
        |> distinct([:corporation_id, :corporation_name])
        |> sort(:corporation_name)
        |> limit(limit)
        |> Api.read!()
        |> Enum.map(fn participant ->
          %{id: participant.corporation_id, name: participant.corporation_name}
        end)

      {:ok, suggestions}
    rescue
      error ->
        {:error, "Corporation search failed: #{inspect(error)}"}
    end
  end

  @doc """
  Get alliance name suggestions based on a search query.

  Queries the participants table to find alliance names that match the search term.
  Returns unique alliance names with their IDs.

  ## Parameters
  - `query` - The search string
  - `opts` - Options including :limit (default: 5)

  ## Returns
  - `{:ok, suggestions}` - List of %{id: alliance_id, name: alliance_name}
  - `{:error, reason}` - Error if query fails
  """
  def get_alliance_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    try do
      suggestions =
        Participant
        |> select([:alliance_id, :alliance_name])
        |> filter(not is_nil(alliance_id) and not is_nil(alliance_name))
        |> filter(ilike(alliance_name, ^"%#{query}%"))
        |> distinct([:alliance_id, :alliance_name])
        |> sort(:alliance_name)
        |> limit(limit)
        |> Api.read!()
        |> Enum.map(fn participant ->
          %{id: participant.alliance_id, name: participant.alliance_name}
        end)

      {:ok, suggestions}
    rescue
      error ->
        {:error, "Alliance search failed: #{inspect(error)}"}
    end
  end

  @doc """
  Get solar system name suggestions based on a search query.

  Queries the eve_solar_systems table to find system names that match the search term.
  Uses PostgreSQL's trigram indexing for efficient fuzzy matching.

  ## Parameters
  - `query` - The search string
  - `opts` - Options including :limit (default: 5)

  ## Returns
  - `{:ok, suggestions}` - List of %{id: system_id, name: system_name}
  - `{:error, reason}` - Error if query fails
  """
  def get_system_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    try do
      suggestions =
        SolarSystem
        |> select([:system_id, :system_name])
        |> filter(ilike(system_name, ^"%#{query}%"))
        |> sort(:system_name)
        |> limit(limit)
        |> Api.read!()
        |> Enum.map(fn system ->
          %{id: system.system_id, name: system.system_name}
        end)

      {:ok, suggestions}
    rescue
      error ->
        {:error, "System search failed: #{inspect(error)}"}
    end
  end

  @doc """
  Get ship type name suggestions based on a search query.

  Queries the eve_item_types table to find ship names that match the search term.
  Filters to only include ship types (specific categories and groups).
  Uses PostgreSQL's trigram indexing for efficient fuzzy matching.

  ## Parameters
  - `query` - The search string
  - `opts` - Options including :limit (default: 5)

  ## Returns
  - `{:ok, suggestions}` - List of %{id: type_id, name: type_name}
  - `{:error, reason}` - Error if query fails
  """
  def get_ship_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    try do
      # Ship category ID is 6 in EVE Online
      # This includes all ships: frigates, cruisers, battleships, etc.
      suggestions =
        ItemType
        |> select([:type_id, :type_name])
        |> filter(category_id == 6)  # Ships category
        |> filter(ilike(type_name, ^"%#{query}%"))
        |> sort(:type_name)
        |> limit(limit)
        |> Api.read!()
        |> Enum.map(fn item_type ->
          %{id: item_type.type_id, name: item_type.type_name}
        end)

      {:ok, suggestions}
    rescue
      error ->
        {:error, "Ship search failed: #{inspect(error)}"}
    end
  end
end