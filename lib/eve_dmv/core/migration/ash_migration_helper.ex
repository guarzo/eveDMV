defmodule EveDmv.Core.Migration.AshMigrationHelper do
  @moduledoc """
  Helper module for migrating from Ecto queries to Ash Framework patterns.
  Provides utilities and patterns for common migration scenarios.
  """

  @doc """
  Converts an Ecto query pattern to Ash query pattern.

  ## Examples

      # Ecto pattern:
      from(k in "killmails_raw",
        where: k.victim_character_id == ^character_id,
        select: k
      )
      
      # Becomes:
      KillmailRaw
      |> new()
      |> filter(victim_character_id == ^character_id)
      |> Ash.read(domain: EveDmv.Api)
  """
  def migrate_query_pattern(ecto_example, ash_example) do
    %{
      ecto_pattern: ecto_example,
      ash_pattern: ash_example,
      migration_notes: analyze_migration_complexity(ecto_example)
    }
  end

  @doc """
  Common Ecto to Ash pattern mappings
  """
  def common_patterns do
    %{
      # Simple where clause
      simple_where: %{
        ecto: "from(r in Resource, where: r.field == ^value)",
        ash: "Resource |> new() |> filter(field == ^value) |> Ash.read(domain: EveDmv.Api)"
      },

      # Multiple conditions
      multiple_conditions: %{
        ecto: "from(r in Resource, where: r.field1 == ^val1 and r.field2 == ^val2)",
        ash:
          "Resource |> new() |> filter(field1 == ^val1 and field2 == ^val2) |> Ash.read(domain: EveDmv.Api)"
      },

      # Ordering
      ordering: %{
        ecto: "from(r in Resource, order_by: [desc: r.created_at])",
        ash: "Resource |> new() |> sort(created_at: :desc) |> Ash.read(domain: EveDmv.Api)"
      },

      # Limit and offset
      pagination: %{
        ecto: "from(r in Resource, limit: ^limit, offset: ^offset)",
        ash:
          "Resource |> new() |> limit(^limit) |> offset(^offset) |> Ash.read(domain: EveDmv.Api)"
      },

      # Aggregations
      count: %{
        ecto: "from(r in Resource, select: count(r.id))",
        ash: "Resource |> new() |> Ash.count(, domain: EveDmv.Api)"
      },

      # Joins (requires relationship)
      joins: %{
        ecto: "from(r in Resource, join: a in assoc(r, :association))",
        ash: "Resource |> new() |> load(:association) |> Ash.read(domain: EveDmv.Api)",
        note: "Requires relationship defined in Ash resource"
      },

      # Insert
      insert: %{
        ecto: "Repo.insert(%Resource{field: value})",
        ash: "Resource |> Ash.Changeset.for_create(:create, %{field: value}) |> Api.create()"
      },

      # Update
      update: %{
        ecto: "Repo.update(changeset)",
        ash: "record |> Ash.Changeset.for_update(:update, attrs) |> Api.update()"
      },

      # Delete
      delete: %{
        ecto: "Repo.delete(record)",
        ash: "Ash.destroy(record, domain: EveDmv.Api)"
      },

      # Bulk insert
      bulk_insert: %{
        ecto: "Repo.insert_all(Resource, records)",
        ash: "Api.bulk_create(Resource, records, upsert?: true)"
      },

      # Transaction
      transaction: %{
        ecto: "Repo.transaction(fn -> ... end)",
        ash: "Api.transaction(fn -> ... end)",
        note: "Ash transactions work similarly but use Api module"
      }
    }
  end

  @doc """
  Migrates a module from Ecto to Ash patterns
  """
  def migrate_module(module_path) do
    # This would analyze a module and suggest migrations
    # For now, returns migration guidelines
    %{
      module: module_path,
      steps: [
        "1. Replace `import Ecto.Query` with `import Ash.Query`",
        "2. Add `alias EveDmv.Api` if not present",
        "3. Replace `Repo.` calls with `Api.` calls",
        "4. Convert `from` queries to Ash query syntax",
        "5. Update changeset operations to use Ash.Changeset",
        "6. Test each converted function thoroughly"
      ],
      common_issues: [
        "Raw SQL queries need special handling",
        "Complex joins may require relationship definitions",
        "Transactions syntax is slightly different",
        "Bulk operations have different options"
      ]
    }
  end

  @doc """
  Validates if an Ash query is equivalent to an Ecto query
  """
  def validate_migration(ecto_query, ash_query, test_data \\ []) do
    # This would run both queries and compare results
    # Placeholder for now
    %{
      ecto_query: inspect(ecto_query),
      ash_query: inspect(ash_query),
      validation_status: :pending,
      test_cases: length(test_data)
    }
  end

  @doc """
  Provides Ash equivalent for common Ecto.Query functions
  """
  def ecto_to_ash_functions do
    %{
      "Ecto.Query.from/2" => "Ash.Query.new/1 |> filter(...)",
      "Ecto.Query.where/3" => "Ash.Query.filter/2",
      "Ecto.Query.select/3" => "Ash.Query.select/2",
      "Ecto.Query.order_by/3" => "Ash.Query.sort/2",
      "Ecto.Query.limit/3" => "Ash.Query.limit/2",
      "Ecto.Query.offset/3" => "Ash.Query.offset/2",
      "Ecto.Query.preload/3" => "Ash.Query.load/2",
      "Ecto.Query.join/5" => "Ash.Query.load/2 (with relationships)",
      "Ecto.Query.group_by/3" => "Ash.Query.group_by/2",
      "Ecto.Query.having/3" => "Use aggregates with filters",
      "Ecto.Query.distinct/3" => "Ash.Query.distinct/2",
      "Repo.all/2" => "Api.read/1",
      "Repo.one/2" => "Api.read_one/1",
      "Repo.get/3" => "Api.get/2",
      "Repo.get!/3" => "Api.get!/2",
      "Repo.insert/2" => "Api.create/1",
      "Repo.update/2" => "Api.update/1",
      "Repo.delete/2" => "Api.destroy/1",
      "Repo.insert_all/3" => "Api.bulk_create/3",
      "Repo.transaction/2" => "Api.transaction/1",
      "Repo.aggregate/4" => "Api.count/1, Api.sum/2, etc."
    }
  end

  @doc """
  Generates migration script for a file
  """
  def generate_migration_script(file_path) do
    """
    #!/bin/bash
    # Migration script for #{file_path}

    # Step 1: Backup original file
    cp #{file_path} #{file_path}.ecto_backup

    # Step 2: Replace imports
    sed -i 's/import Ecto.Query/import Ash.Query/g' #{file_path}
    sed -i 's/alias.*Repo/alias EveDmv.Api/g' #{file_path}

    # Step 3: Replace Repo calls with Api
    sed -i 's/Repo\\.all(/Api.read(/g' #{file_path}
    sed -i 's/Repo\\.one(/Api.read_one(/g' #{file_path}
    sed -i 's/Repo\\.get(/Api.get(/g' #{file_path}
    sed -i 's/Repo\\.insert(/Api.create(/g' #{file_path}
    sed -i 's/Repo\\.update(/Api.update(/g' #{file_path}
    sed -i 's/Repo\\.delete(/Api.destroy(/g' #{file_path}

    # Step 4: Manual review required for:
    # - from() queries
    # - Complex joins
    # - Raw SQL
    # - Changesets

    echo "Basic migration complete. Manual review required for complex queries."
    """
  end

  defp analyze_migration_complexity(ecto_query) do
    cond do
      String.contains?(ecto_query, "fragment(") ->
        "Complex: Contains SQL fragments that need special handling"

      String.contains?(ecto_query, "join:") ->
        "Medium: Contains joins that need relationship definitions"

      String.contains?(ecto_query, "subquery(") ->
        "Complex: Contains subqueries that need restructuring"

      true ->
        "Simple: Straightforward conversion possible"
    end
  end
end
