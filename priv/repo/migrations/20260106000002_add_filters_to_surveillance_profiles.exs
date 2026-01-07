defmodule EveDmv.Repo.Migrations.AddFiltersToSurveillanceProfiles do
  @moduledoc """
  Adds the filters column to surveillance_profiles table.

  The Profile resource defines a `filters` attribute as an array of embedded
  SimpleFilter resources, but the original migration didn't include this column.
  """

  use Ecto.Migration

  def up do
    alter table(:surveillance_profiles) do
      add(:filters, {:array, :map}, null: false, default: fragment("'{}'::jsonb[]"))
    end
  end

  def down do
    alter table(:surveillance_profiles) do
      remove(:filters)
    end
  end
end
