defmodule EveDmvWeb.Api.BattleIntelligenceController do
  use EveDmvWeb, :controller

  alias EveDmv.Contexts.BattleAnalysis

  @doc """
  GET /api/v1/battles/:id/intelligence

  Returns comprehensive intelligence analysis for a battle.
  """
  def show(conn, %{"id" => battle_id}) do
    case BattleAnalysis.get_battle_intelligence_summary(battle_id) do
      {:ok, intelligence} ->
        json(conn, %{
          data: %{
            battle_id: battle_id,
            intelligence: intelligence.intelligence,
            timeline: intelligence.timeline,
            summary: intelligence.summary
          }
        })

      {:error, :battle_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Battle not found", code: "BATTLE_NOT_FOUND"}})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Failed to load battle intelligence", code: "INTERNAL_ERROR"}})
    end
  end
end
