defmodule EveDmv.Contexts.KillmailProcessing.Domain.KillmailQueryService do
  @moduledoc """
  Service for querying killmail data.

  Handles all killmail query operations including retrieving individual
  killmails, filtering by system/character, and fetching high-value kills.
  """

  import Ash.Expr

  alias EveDmv.Contexts.KillmailProcessing.Domain.KillmailValidators
  alias EveDmv.Result
  alias EveDmv.SharedKernel.ValueObjects.CharacterId
  alias EveDmv.SharedKernel.ValueObjects.SolarSystemId

  require Ash.Query

  @type killmail_options :: [
          limit: integer(),
          offset: integer(),
          min_value: integer(),
          max_value: integer()
        ]

  @doc """
  Get a specific killmail by ID.

  Returns both the killmail and its type (enriched or raw).
  """
  @spec get_by_id(integer()) :: Result.t(map()) | {:error, :not_found | :invalid_killmail_id}
  def get_by_id(killmail_id) when is_integer(killmail_id) and killmail_id > 0 do
    case get_enriched_killmail(killmail_id) do
      {:ok, enriched} ->
        {:ok, build_result(enriched, :enriched)}

      {:error, _} ->
        get_raw_killmail_fallback(killmail_id)
    end
  end

  def get_by_id(_), do: {:error, :invalid_killmail_id}

  @doc """
  Get recent killmails with optional filtering.
  """
  @spec get_recent(killmail_options()) :: Result.t([map()])
  def get_recent(opts \\ []) do
    case KillmailValidators.validate_killmail_options(opts) do
      :ok ->
        limit = Keyword.get(opts, :limit, 100)

        EveDmv.Killmails.KillmailEnriched
        |> Ash.Query.limit(limit)
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.read()

      error ->
        error
    end
  end

  @doc """
  Get killmails for a specific solar system.
  """
  @spec get_by_system(integer(), killmail_options()) :: Result.t([map()])
  def get_by_system(system_id, opts \\ []) do
    with {:ok, _system_id_vo} <- SolarSystemId.new(system_id),
         :ok <- KillmailValidators.validate_killmail_options(opts) do
      limit = Keyword.get(opts, :limit, 100)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.filter(solar_system_id: system_id)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.read()
    end
  end

  @doc """
  Get killmails involving a specific character.
  """
  @spec get_by_character(integer(), killmail_options()) :: Result.t([map()])
  def get_by_character(character_id, opts \\ []) do
    with {:ok, _character_id_vo} <- CharacterId.new(character_id),
         :ok <- KillmailValidators.validate_killmail_options(opts) do
      limit = Keyword.get(opts, :limit, 100)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.filter(victim_character_id: character_id)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.read()
    end
  end

  @doc """
  Get high-value killmails above a threshold.
  """
  @spec get_high_value(killmail_options()) :: Result.t([map()])
  def get_high_value(opts \\ []) do
    # Default minimum: 1B ISK
    opts_with_defaults = Keyword.put_new(opts, :min_value, 1_000_000_000)

    case KillmailValidators.validate_killmail_options(opts_with_defaults) do
      :ok ->
        limit = Keyword.get(opts_with_defaults, :limit, 100)
        min_value = Keyword.get(opts_with_defaults, :min_value, 1_000_000_000)

        EveDmv.Killmails.KillmailEnriched
        |> Ash.Query.filter(expr(total_value >= ^min_value))
        |> Ash.Query.limit(limit)
        |> Ash.Query.sort(total_value: :desc)
        |> Ash.read()

      error ->
        error
    end
  end

  # Private functions

  defp get_enriched_killmail(killmail_id) do
    Ash.get(EveDmv.Killmails.KillmailEnriched, killmail_id, domain: EveDmv.Api)
  end

  defp get_raw_killmail_fallback(killmail_id) do
    case Ash.get(EveDmv.Killmails.KillmailRaw, killmail_id, domain: EveDmv.Api) do
      {:ok, raw} ->
        {:ok, build_result(raw, :raw)}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp build_result(killmail, type) do
    %{
      killmail: killmail,
      type: type,
      found_at: DateTime.utc_now()
    }
  end
end
