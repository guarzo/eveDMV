defmodule EveDmv.Repo.Migrations.AddAdminFieldToUsers do
  use Ecto.Migration

  def change do
    # Check if column already exists before adding it
    execute """
      DO $$ 
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'users' AND column_name = 'is_admin') 
        THEN
          ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE NOT NULL;
          COMMENT ON COLUMN users.is_admin IS 'Whether this user has admin privileges';
        END IF;
      END $$;
    """, ""

    # Create index for admin user lookups (only if it doesn't exist)
    execute """
      DO $$ 
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'users_is_admin_index') 
        THEN
          CREATE INDEX users_is_admin_index ON users (is_admin) WHERE is_admin = true;
        END IF;
      END $$;
    """, "DROP INDEX IF EXISTS users_is_admin_index"
  end
end