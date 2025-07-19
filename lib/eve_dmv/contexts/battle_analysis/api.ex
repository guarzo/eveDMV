defmodule EveDmv.Contexts.BattleAnalysis.Api do
  @moduledoc """
  Ash API domain for battle analysis resources.

  This domain manages resources related to combat log analysis,
  ship fittings, and battle correlation functionality.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    # Core battle analysis resources
    resource(EveDmv.Contexts.BattleAnalysis.Resources.Battle)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail)

    # Combat log and fitting analysis
    resource(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
