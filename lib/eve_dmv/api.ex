defmodule EveDmv.Api do
  @moduledoc """
  The main Ash API for the EVE PvP Tracker application.

  This API contains core resources needed for the application's primary
  functionality. Additional specialized resources are managed through
  focused sub-domains to reduce complexity and dependencies.

  Sub-domains:
  - EveDmv.Api.SurveillanceApi - Surveillance resources
  - EveDmv.Api.AnalyticsApi - Analytics resources
  - EveDmv.Api.BattleAnalysisApi - Battle analysis resources
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  # Core application resources only
  resources do
    # Essential user and authentication
    resource(EveDmv.Users.User)
    resource(EveDmv.Users.Token)
    resource(EveDmv.Security.ApiAuthentication)

    # Primary killmail data
    resource(EveDmv.Killmails.KillmailRaw)
    # REMOVED: KillmailEnriched - see /docs/architecture/enriched-raw-analysis.md
    resource(EveDmv.Killmails.Participant)

    # Battle analysis resources (must be in same domain as KillmailRaw)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.Battle)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail)

    # Essential EVE static data
    resource(EveDmv.Eve.ItemType)
    resource(EveDmv.Eve.SolarSystem)

    # Core intelligence resources
    resource(EveDmv.Intelligence.CharacterStats)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
