defmodule EveDmvWeb.Api.CharacterBehaviorController do
  @moduledoc """
  API controller for character behavioral pattern analysis.

  Provides endpoints for analyzing and retrieving behavioral
  patterns and characteristics of EVE Online characters.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.CharacterIntelligence

  @doc """
  GET /api/v1/characters/:id/behavioral_patterns

  Returns behavioral pattern analysis for a character.
  """
  def show(conn, %{"id" => character_id_str}) do
    character_id = String.to_integer(character_id_str)

    case CharacterIntelligence.detect_behavioral_patterns(character_id) do
      {:ok, patterns} ->
        json(conn, %{
          data: %{
            character_id: character_id,
            primary_pattern: patterns.primary_pattern,
            patterns: patterns.patterns,
            characteristics: patterns.characteristics
          }
        })

      {:error, reason} ->
        {status, message, code} = case reason do
          :insufficient_data -> {:unprocessable_entity, "Insufficient data to analyze behavioral patterns", "INSUFFICIENT_DATA"}
          _other -> {:internal_server_error, "Failed to analyze behavioral patterns", "INTERNAL_ERROR"}
        end

        conn
        |> put_status(status)
        |> json(%{error: %{message: message, code: code}})
    end
  end
end
