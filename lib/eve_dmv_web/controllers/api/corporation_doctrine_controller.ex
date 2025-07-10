defmodule EveDmvWeb.Api.CorporationDoctrineController do
  use EveDmvWeb, :controller

  alias EveDmv.Contexts.CorporationIntelligence

  @doc """
  GET /api/v1/corporations/:id/doctrine_analysis

  Returns combat doctrine analysis for a corporation.
  """
  def show(conn, %{"id" => corporation_id_str}) do
    corporation_id = String.to_integer(corporation_id_str)

    case CorporationIntelligence.analyze_combat_doctrines(corporation_id) do
      {:ok, analysis} ->
        json(conn, %{
          data: %{
            corporation_id: corporation_id,
            primary_doctrine: analysis.primary_doctrine,
            doctrine_confidence: analysis.doctrine_confidence,
            secondary_doctrines: analysis.secondary_doctrines,
            fleet_compositions: analysis.fleet_compositions,
            tactical_preferences: analysis.tactical_preferences
          }
        })

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: %{message: "Failed to analyze corporation doctrines", code: "INTERNAL_ERROR"}
        })
    end
  end
end
