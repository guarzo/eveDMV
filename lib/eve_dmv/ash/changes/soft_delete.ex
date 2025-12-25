defmodule EveDmv.Ash.Changes.SoftDelete do
  @moduledoc """
  Standardized soft delete change for Ash resources.

  This module provides a consistent soft delete implementation that can be
  reused across resources that need soft delete functionality.

  ## Usage

  Add the `deleted_at` attribute to your resource:

      attributes do
        attribute :deleted_at, :utc_datetime do
          description("Soft delete timestamp")
          allow_nil?(true)
        end
      end

  Add base filters to exclude soft-deleted records by default:

      resource do
        base_filter(expr(is_nil(deleted_at)))
      end

      postgres do
        base_filter_sql("deleted_at IS NULL")
      end

  Define a soft_delete action using this change:

      actions do
        update :soft_delete do
          accept([])
          require_atomic?(false)
          change {EveDmv.Ash.Changes.SoftDelete, []}
        end

        # Or for hard delete with soft delete check
        destroy :destroy do
          change {EveDmv.Ash.Changes.SoftDelete, action: :hard_delete}
        end
      end

  Optionally, add a restore action:

      update :restore do
        accept([])
        require_atomic?(false)
        change {EveDmv.Ash.Changes.SoftDelete, action: :restore}
      end

  ## Options

  - `:action` - The action to perform:
    - `:soft_delete` (default) - Sets deleted_at to current timestamp
    - `:restore` - Sets deleted_at to nil
    - `:hard_delete` - Allows hard delete (no change made)
  - `:timestamp_field` - The field to use for soft delete (default: `:deleted_at`)

  ## Resources Using Soft Delete

  The following resources in EVE DMV use soft delete:
  - `EveDmv.Contexts.Combat.Resources.Battle`
  - `EveDmv.Contexts.BattleAnalysis.Resources.Battle`
  - `EveDmv.Contexts.BattleAnalysis.Resources.BattleReport`
  - `EveDmv.Contexts.BattleAnalysis.Resources.BattleReportComment`
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    action = Keyword.get(opts, :action, :soft_delete)
    field = Keyword.get(opts, :timestamp_field, :deleted_at)

    case action do
      :soft_delete ->
        Ash.Changeset.change_attribute(changeset, field, DateTime.utc_now())

      :restore ->
        Ash.Changeset.change_attribute(changeset, field, nil)

      :hard_delete ->
        # No change for hard delete - just pass through
        changeset
    end
  end

  @doc """
  Check if a record is soft deleted.

  Optionally specify the timestamp field to check (default: :deleted_at).

  ## Examples

      iex> SoftDelete.deleted?(%{deleted_at: ~U[2025-01-01 00:00:00Z]})
      true

      iex> SoftDelete.deleted?(%{deleted_at: nil})
      false

      iex> SoftDelete.deleted?(%{archived_at: ~U[2025-01-01 00:00:00Z]}, :archived_at)
      true
  """
  @spec deleted?(map(), atom()) :: boolean()
  def deleted?(record, field \\ :deleted_at) when is_map(record) do
    case Map.get(record, field) do
      nil -> false
      %DateTime{} -> true
      _ -> false
    end
  end

  @doc """
  Check if a record is active (not soft deleted).

  Optionally specify the timestamp field to check (default: :deleted_at).

  ## Examples

      iex> SoftDelete.active?(%{deleted_at: nil})
      true

      iex> SoftDelete.active?(%{deleted_at: ~U[2025-01-01 00:00:00Z]})
      false

      iex> SoftDelete.active?(%{archived_at: nil}, :archived_at)
      true
  """
  @spec active?(map(), atom()) :: boolean()
  def active?(record, field \\ :deleted_at) when is_map(record) do
    not deleted?(record, field)
  end
end
