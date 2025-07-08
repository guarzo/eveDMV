defmodule EveDmv.Killmails.EnrichedParticipantLoader do
  @moduledoc """
  Helper module for loading participants for KillmailEnriched records.

  Since Ash doesn't support composite foreign key relationships,
  this module provides utilities to manually load participants
  for enriched killmails.
  """

  import Ash.Expr

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailEnriched
  alias EveDmv.Killmails.Participant

  require Ash.Query

  @doc """
  Load participants for a single KillmailEnriched record.

  Returns the enriched killmail with a `participants` field containing
  all participants (attackers and victim) for this killmail.
  """
  @spec load_participants(KillmailEnriched.t()) :: map()
  def load_participants(%KillmailEnriched{} = killmail) do
    participants = get_participants(killmail.killmail_id, killmail.killmail_time)
    Map.put(killmail, :participants, participants)
  end

  @doc """
  Load participants for multiple KillmailEnriched records efficiently.

  Uses a single query to load all participants and then groups them
  by killmail to avoid N+1 queries.
  """
  @spec load_participants_batch([KillmailEnriched.t()]) :: [map()]
  def load_participants_batch(killmails) when is_list(killmails) do
    # Extract killmail identifiers
    killmail_keys =
      Enum.map(killmails, fn km ->
        {km.killmail_id, km.killmail_time}
      end)

    # Load all participants for these killmails in one query
    participants_by_killmail = get_participants_batch(killmail_keys)

    # Attach participants to each killmail
    Enum.map(killmails, fn killmail ->
      key = {killmail.killmail_id, killmail.killmail_time}
      participants = Map.get(participants_by_killmail, key, [])
      Map.put(killmail, :participants, participants)
    end)
  end

  @doc """
  Get participants for a specific killmail.
  """
  @spec get_participants(integer(), DateTime.t()) :: [Participant.t()]
  def get_participants(killmail_id, killmail_time) do
    Participant
    |> Ash.Query.new()
    |> Ash.Query.filter(killmail_id == ^killmail_id and killmail_time == ^killmail_time)
    |> Ash.Query.sort(is_victim: :desc, final_blow: :desc, damage_done: :desc)
    |> Ash.read!(domain: Api)
  end

  @doc """
  Get participants for multiple killmails efficiently.

  Returns a map with {killmail_id, killmail_time} tuples as keys
  and lists of participants as values.
  """
  @spec get_participants_batch([{integer(), DateTime.t()}]) :: %{
          {integer(), DateTime.t()} => [Participant.t()]
        }
  def get_participants_batch(killmail_keys) when is_list(killmail_keys) do
    if Enum.empty?(killmail_keys) do
      %{}
    else
      # Build filter conditions for all killmails
      filter_conditions = build_batch_filter(killmail_keys)

      # Load all participants
      participants =
        Participant
        |> Ash.Query.new()
        |> Ash.Query.filter(^filter_conditions)
        |> Ash.Query.sort(
          killmail_id: :asc,
          killmail_time: :asc,
          is_victim: :desc,
          final_blow: :desc
        )
        |> Ash.read!(domain: Api)

      # Filter to only the exact killmail keys we want and group by killmail
      killmail_key_set = MapSet.new(killmail_keys)

      Enum.group_by(
        Enum.filter(participants, fn p ->
          MapSet.member?(killmail_key_set, {p.killmail_id, p.killmail_time})
        end),
        fn p ->
          {p.killmail_id, p.killmail_time}
        end
      )
    end
  end

  @doc """
  Get only attackers for a killmail (excluding victim).
  """
  @spec get_attackers(integer(), DateTime.t()) :: [Participant.t()]
  def get_attackers(killmail_id, killmail_time) do
    Participant
    |> Ash.Query.new()
    |> Ash.Query.filter(
      killmail_id == ^killmail_id and
        killmail_time == ^killmail_time and
        is_victim == false
    )
    |> Ash.Query.sort(final_blow: :desc, damage_done: :desc)
    |> Ash.read!(domain: Api)
  end

  @doc """
  Get only the victim for a killmail.
  """
  @spec get_victim(integer(), DateTime.t()) :: Participant.t() | nil
  def get_victim(killmail_id, killmail_time) do
    Participant
    |> Ash.Query.new()
    |> Ash.Query.filter(
      killmail_id == ^killmail_id and
        killmail_time == ^killmail_time and
        is_victim == true
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(domain: Api)
    |> List.first()
  end

  # Private helper to build efficient batch filter
  defp build_batch_filter(killmail_keys) do
    # For now, use a simpler approach with IN queries on killmail_id
    # and then filter by time in memory if needed
    killmail_ids = killmail_keys |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
    expr(killmail_id in ^killmail_ids)
  end
end
