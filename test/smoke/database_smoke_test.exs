defmodule EveDmv.Smoke.DatabaseSmokeTest do
  use EveDmv.DataCase, async: false

  describe "database connectivity" do
    test "can connect to database" do
      result = Ecto.Adapters.SQL.query!(EveDmv.Repo, "SELECT 1 as num")
      assert result.rows == [[1]]
    end

    test "migrations are up to date" do
      {:ok, versions, _} =
        Ecto.Migrator.with_repo(EveDmv.Repo, fn repo ->
          Ecto.Migrator.migrated_versions(repo)
        end)

      assert length(versions) > 0, "No migrations found"
    end
  end

  describe "partitioned tables" do
    test "killmails_raw table exists and is partitioned" do
      query = "SELECT tablename FROM pg_tables WHERE tablename LIKE 'killmails_raw%'"
      result = Ecto.Adapters.SQL.query!(EveDmv.Repo, query)
      assert length(result.rows) > 0, "No killmail partitions found"
    end

    test "can query killmails_raw partitioned table" do
      # Test that we can query the parent table
      query =
        "SELECT COUNT(*) FROM killmails_raw WHERE killmail_time > NOW() - INTERVAL '30 days'"

      result = Ecto.Adapters.SQL.query!(EveDmv.Repo, query)
      assert result.rows != nil
    end
  end

  describe "essential tables" do
    test "core tables exist" do
      tables = [
        "users",
        "tokens",
        "eve_item_types",
        "eve_solar_systems",
        "character_stats"
      ]

      for table <- tables do
        query = "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = $1"
        result = Ecto.Adapters.SQL.query!(EveDmv.Repo, query, [table])
        [[count]] = result.rows
        assert count == 1, "Table #{table} does not exist"
      end
    end
  end
end
