defmodule EveDmvWeb.Api.BattleRatingController do
  @moduledoc """
  API controller for battle report rating functionality.

  Allows users to rate shared battle reports and manages
  the rating aggregation system.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.BattleSharing

  @doc """
  POST /api/v1/battles/:id/rate

  Rates a battle report.
  """
  def create(conn, %{"id" => report_id, "rating" => rating}) do
    # In production, get character_id from authenticated user
    rater_id = conn.assigns[:current_user_id] || 12345

    rating_value =
      case rating do
        r when is_integer(r) -> r
        r when is_binary(r) -> String.to_integer(r)
        _ -> 3
      end

    case BattleSharing.rate_battle_report(report_id, rater_id, rating_value) do
      {:ok, result} ->
        json(conn, %{
          data: %{
            success: true,
            new_average: result[:new_average] || 0,
            total_ratings: result[:total_ratings] || 0
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Failed to rate battle report", details: inspect(reason)}})
    end
  end
end
