defmodule EveDmv.Api do
  @moduledoc """
  The main Ash API for the EVE PvP Tracker application.

  This API contains core resources needed for the application's primary
  functionality. Additional specialized resources are managed through
  focused sub-domains to reduce complexity and dependencies.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  # Core application resources
  resources do
    # Essential user and authentication
    resource(EveDmv.Users.User)
    resource(EveDmv.Users.Token)
    resource(EveDmv.Security.ApiAuthentication)

    # Primary killmail data
    resource(EveDmv.Killmails.KillmailRaw)
    # REMOVED: KillmailEnriched - see /docs/architecture/enriched-raw-analysis.md
    resource(EveDmv.Killmails.Participant)

    # Essential EVE static data
    resource(EveDmv.Eve.ItemType)
    resource(EveDmv.Eve.SolarSystem)

    # Core intelligence resources
    resource(EveDmv.Intelligence.CharacterStats)

    # Surveillance resources
    resource(EveDmv.Surveillance.Profile)
    resource(EveDmv.Surveillance.ProfileMatch)
    resource(EveDmv.Surveillance.Notification)

    # Analytics resources
    resource(EveDmv.Analytics.ShipStats)
    resource(EveDmv.Analytics.PlayerStats)

    # Battle Analysis resources
    resource(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
