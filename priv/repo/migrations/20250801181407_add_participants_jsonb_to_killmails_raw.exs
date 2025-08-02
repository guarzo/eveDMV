defmodule EveDmv.Repo.Migrations.AddParticipantsJsonbToKillmailsRaw do
  use Ecto.Migration

  def change do
    alter table(:killmails_raw) do
      add :participants, :jsonb
    end

    # Add GIN index for JSONB containment queries
    create index(:killmails_raw, [:participants], 
      name: :killmails_raw_participants_gin_idx, 
      using: "GIN"
    )
  end
end