defmodule EveDmv.Repo.Migrations.AddAccountsTable do
  @moduledoc """
  Create accounts table and add account_id to users table for multi-character support.
  
  This migration enables multi-character support by:
  1. Creating an accounts table to group multiple characters
  2. Adding account_id foreign key to users table
  3. Creating necessary indexes for performance
  """
  
  use Ecto.Migration

  def up do
    # Create accounts table
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      
      # Account metadata
      add :primary_character_id, :binary_id, null: true
      add :account_name, :string, size: 255, null: true
      
      # Activity tracking
      add :last_login_at, :utc_datetime, null: true
      add :last_character_switch_at, :utc_datetime, null: true
      
      # Admin privileges (inherited by all characters)
      add :is_admin, :boolean, null: false, default: false
      
      timestamps()
    end
    
    # Add indexes for accounts table
    create index(:accounts, [:primary_character_id])
    create index(:accounts, [:last_login_at])
    create index(:accounts, [:is_admin])
    
    # Add account_id column to users table
    alter table(:users) do
      add :account_id, :binary_id, null: true
    end
    
    # Add index for account_id foreign key
    create index(:users, [:account_id])
    
    # Add foreign key constraint
    alter table(:accounts) do
      modify :primary_character_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
    
    alter table(:users) do  
      modify :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all)
    end
  end

  def down do
    # Remove foreign key constraints
    alter table(:users) do
      modify :account_id, :binary_id, null: true
    end
    
    alter table(:accounts) do
      modify :primary_character_id, :binary_id, null: true
    end
    
    # Remove account_id column from users
    alter table(:users) do
      remove :account_id
    end
    
    # Drop accounts table
    drop table(:accounts)
  end
end