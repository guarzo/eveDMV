defmodule EveDmv.Ash.Preparations.SoftDeleteFilter do
  @moduledoc """
  Ash preparation to automatically filter out soft-deleted records.

  Add this preparation to resources that have a `deleted_at` attribute to
  automatically exclude deleted records from read queries.

  ## Usage

  In your resource's preparations block:

      preparations do
        prepare EveDmv.Ash.Preparations.SoftDeleteFilter
      end

  Or in a specific read action:

      read :list do
        prepare EveDmv.Ash.Preparations.SoftDeleteFilter
      end

  ## Options

    * `:include_deleted` - Set to `true` to bypass the filter (for admin queries)

  ## Note

  For resources using AshPostgres, you may also want to use `base_filter_sql`
  in the postgres block for database-level filtering that applies to all queries
  including those from relationships:

      postgres do
        table "my_table"
        repo EveDmv.Repo
        base_filter_sql "deleted_at IS NULL"
      end

  This preparation is useful when you want soft delete filtering at the Ash query
  level rather than the database level, or when you need the ability to include
  deleted records conditionally.
  """

  use Ash.Resource.Preparation
  import Ash.Expr
  require Ash.Query

  @impl Ash.Resource.Preparation
  def prepare(query, opts, _context) do
    include_deleted = Keyword.get(opts, :include_deleted, false)

    if include_deleted do
      query
    else
      Ash.Query.filter(query, expr(is_nil(deleted_at)))
    end
  end
end
