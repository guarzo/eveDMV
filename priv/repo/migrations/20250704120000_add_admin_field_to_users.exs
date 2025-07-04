defmodule EveDmv.Repo.Migrations.AddAdminFieldToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false,
        comment: "Whether this user has admin privileges"
    end

    # Create index for admin user lookups
    create index(:users, [:is_admin], 
      where: "is_admin = true",
      comment: "Optimizes admin user lookups")
  end
end