defmodule EveDmvWeb.Api.BattleIntelligenceController do
  @moduledoc """
  API controller for battle intelligence analysis.

  Provides endpoints for retrieving comprehensive intelligence
  summaries and analysis for specific battles.
  """

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

      {:error, reason} ->
        {status, message, code} =
          case reason do
            :battle_not_found ->
              {:not_found, "Battle not found", "BATTLE_NOT_FOUND"}

            :database_error ->
              {:internal_server_error, "Database error occurred", "DATABASE_ERROR"}

            :max_iterations_reached ->
              {:internal_server_error, "Battle analysis timed out", "ANALYSIS_TIMEOUT"}

            _ ->
              {:internal_server_error, "Failed to load battle intelligence", "INTERNAL_ERROR"}
          end

        conn
        |> put_status(status)
        |> json(%{error: %{message: message, code: code}})
    end
  end
end
