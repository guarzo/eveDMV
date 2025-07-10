defmodule EveDmvWeb.Api.CharacterThreatController do
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
            threat_score: threat_analysis.threat_score || threat_analysis.overall_score,
            threat_level: threat_analysis.threat_level,
            dimensions: threat_analysis.dimensions,
            analysis_period: threat_analysis.analysis_period,
            data_points: threat_analysis.data_points
          }
        })

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Failed to analyze character threat", code: "INTERNAL_ERROR"}})
    end
  end
end
