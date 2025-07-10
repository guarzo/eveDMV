defmodule EveDmv.Repo.Migrations.FixPgStatStatementsExtension do
  use Ecto.Migration

  def up do
    # First check if we're running as superuser (required for pg_stat_statements)
    # This handles both local dev and production environments gracefully
    execute """
    DO $$
    BEGIN
      -- Check if we have superuser privileges
      IF EXISTS (
        SELECT 1 FROM pg_roles 
        WHERE rolname = current_user AND rolsuper = true
      ) THEN
        -- Only try to create the extension if we're superuser
        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      ELSE
        -- Log a notice that we can't create the extension
        RAISE NOTICE 'pg_stat_statements extension requires superuser privileges - skipping';
      END IF;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to create pg_stat_statements extension - skipping';
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create pg_stat_statements extension: %', SQLERRM;
    END $$;
    """
    
    # These extensions don't require special privileges
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist"
  end

  def down do
    # Only drop if we have the privileges
    execute """
    DO $$
    BEGIN
      DROP EXTENSION IF EXISTS pg_stat_statements;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Insufficient privileges to drop pg_stat_statements extension';
    END $$;
    """
    
    execute "DROP EXTENSION IF EXISTS pg_trgm"
    execute "DROP EXTENSION IF EXISTS btree_gin"
    execute "DROP EXTENSION IF EXISTS btree_gist"
  end
end