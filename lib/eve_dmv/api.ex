defmodule EveDmv.Api do
  @moduledoc """
  The main Ash API for the EVE PvP Tracker application.

  This API contains all the resources and is the central point for interacting
  with our domain data including users, killmails, participants, and EVE item types.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  # Domain resources
  resources do
    # User management
    resource(EveDmv.Users.User)
    resource(EveDmv.Users.Token)

    # Killmail data
    resource(EveDmv.Killmails.KillmailRaw)
    resource(EveDmv.Killmails.KillmailEnriched)
    resource(EveDmv.Killmails.Participant)

    # Static EVE data
    resource(EveDmv.Eve.ItemType)
    resource(EveDmv.Eve.SolarSystem)

    # Intelligence data
    resource(EveDmv.Intelligence.CharacterStats)
    resource(EveDmv.Intelligence.ChainTopology)
    resource(EveDmv.Intelligence.SystemInhabitant)
    resource(EveDmv.Intelligence.ChainConnection)
    resource(EveDmv.Intelligence.WHVetting)
    resource(EveDmv.Intelligence.HomeDefenseAnalytics)
    resource(EveDmv.Intelligence.WHFleetComposition)
    resource(EveDmv.Intelligence.MemberActivityIntelligence)

    # Surveillance profiles
    resource(EveDmv.Surveillance.Profile)
    resource(EveDmv.Surveillance.ProfileMatch)
    resource(EveDmv.Surveillance.Notification)

    # Analytics resources
    resource(EveDmv.Analytics.PlayerStats)
    resource(EveDmv.Analytics.ShipStats)

    # Security resources
    resource(EveDmv.Security.ApiAuthentication)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
