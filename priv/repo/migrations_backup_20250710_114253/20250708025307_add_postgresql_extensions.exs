defmodule EveDmv.Repo.Migrations.AddPostgresqlExtensions do
  use Ecto.Migration

  def change do
    # Enable PostgreSQL extensions for performance monitoring and fuzzy search
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements", "DROP EXTENSION IF EXISTS pg_stat_statements"
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"
    
    # Optionally enable other useful extensions
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin", "DROP EXTENSION IF EXISTS btree_gin"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist", "DROP EXTENSION IF EXISTS btree_gist"
  end
end
