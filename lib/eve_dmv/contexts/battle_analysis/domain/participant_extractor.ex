defmodule EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor do
  @moduledoc """
  Utility module for extracting participant information from killmail data.
  """

  @doc """
  Extracts all participant character IDs from a killmail.
  Returns a list of character IDs including both victim and attackers.
  """
  def extract_participants(killmail) do
    participants = [killmail.victim_character_id]

    # Extract attacker character IDs from raw_data
    attackers =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["character_id"])
          |> Enum.filter(&(&1 != nil))
          |> Enum.map(fn
            id when is_binary(id) -> String.to_integer(id)
            id when is_integer(id) -> id
          end)

        _ ->
          []
      end

    participants ++ attackers
  end

  @doc """
  Extracts attacker character IDs from a killmail's raw data.
  Returns a list of character IDs for attackers only.
  """
  def extract_attackers(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.map(& &1["character_id"])
        |> Enum.filter(&(&1 != nil))
        |> Enum.map(fn
          id when is_binary(id) -> String.to_integer(id)
          id when is_integer(id) -> id
        end)

      _ ->
        []
    end
  end
end
