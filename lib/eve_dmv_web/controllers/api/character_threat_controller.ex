defmodule EveDmvWeb.Api.CharacterThreatController do
  @moduledoc """
  API controller for character threat assessment.

  Provides endpoints for analyzing and retrieving threat scores
  and risk assessments for EVE Online characters.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.CharacterIntelligence

  @doc """
  GET /api/v1/characters/:id/threat_score

  Returns threat score analysis for a character.
  """
  def show(conn, %{"id" => character_id_str}) do
    character_id = String.to_integer(character_id_str)

    case CharacterIntelligence.analyze_character_threat(character_id) do
      {:ok, threat_analysis} ->
        json(conn, %{
          data: %{
            character_id: character_id,
            threat_score: threat_analysis.threat_score,
            threat_level: threat_analysis.threat_level,
            dimensions: threat_analysis.dimensions,
            analysis_period: threat_analysis.analysis_period,
            data_points: threat_analysis.data_points
          }
        })

      {:error, reason} ->
        {status, message, code} = 
          case reason do
            :insufficient_data -> 
              {:unprocessable_entity, "Insufficient data to analyze character threat", "INSUFFICIENT_DATA"}
            :character_not_found -> 
              {:not_found, "Character not found", "CHARACTER_NOT_FOUND"}
            :analysis_failed -> 
              {:internal_server_error, "Analysis failed", "ANALYSIS_FAILED"}
            _ -> 
              {:internal_server_error, "Failed to analyze character threat", "INTERNAL_ERROR"}
          end

        conn
        |> put_status(status)
        |> json(%{error: %{message: message, code: code}})
    end
  end
end
