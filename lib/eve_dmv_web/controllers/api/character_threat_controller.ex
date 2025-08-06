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
            threat_score: threat_analysis.overall_score,
            threat_level: threat_analysis.threat_level,
            threat_classification: threat_analysis.threat_classification,
            key_strengths: threat_analysis.key_strengths,
            key_weaknesses: threat_analysis.key_weaknesses,
            detailed_breakdown: Map.get(threat_analysis, :detailed_breakdown),
            metadata: threat_analysis.metadata
          }
        })

      {:error, :insufficient_data} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            message: "Insufficient data to analyze character threat",
            code: "INSUFFICIENT_DATA"
          }
        })

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Failed to analyze character threat", code: "INTERNAL_ERROR"}})
    end
  end
end
