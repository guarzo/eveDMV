defmodule EveDmv.Repo.Migrations.AddTotalValueToKillmailsRaw do
  use Ecto.Migration

  def change do
    alter table(:killmails_raw) do
      add :total_value, :decimal, precision: 15, scale: 2
    end
  end
end
