defmodule EveDmvWeb.Api.CorporationThreatController do
  use EveDmvWeb, :controller
  
  alias EveDmv.Contexts.CorporationIntelligence
  
  @doc """
  GET /api/v1/corporations/:id/threat_assessment
  
  Returns comprehensive threat assessment for a corporation.
  """
  def show(conn, %{"id" => corporation_id_str}) do
    corporation_id = String.to_integer(corporation_id_str)
    
    case CorporationIntelligence.get_corporation_intelligence_report(corporation_id) do
      {:ok, report} ->
        json(conn, %{
          data: %{
            corporation_id: corporation_id,
            threat_level: report.summary.threat_level,
            primary_doctrine: report.summary.primary_doctrine,
            average_member_threat: report.summary.average_member_threat,
            key_capabilities: report.summary.key_capabilities,
            vulnerabilities: report.summary.vulnerabilities,
            recommendations: report.summary.recommendations
          }
        })
      
      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Failed to assess corporation threat", code: "INTERNAL_ERROR"}})
    end
  end
end