defmodule EveDmv.Repo.Migrations.RemoveEnrichedShipTypeFk do
  use Ecto.Migration

  def change do
    # This migration is obsolete since killmails_enriched table has been removed
    # See migration 20250708174743_drop_enriched_killmails_table.exs
    # No operation needed
  end
end