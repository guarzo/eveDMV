defmodule EveDmv.Repo.Migrations.AddItemTypeClassificationColumns do
  @moduledoc """
  Adds is_drone, is_implant, and is_fighter classification columns to eve_item_types.
  """
  use Ecto.Migration

  def up do
    alter table(:eve_item_types) do
      add :is_drone, :boolean, null: false, default: false
      add :is_implant, :boolean, null: false, default: false
      add :is_fighter, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:eve_item_types) do
      remove :is_drone
      remove :is_implant
      remove :is_fighter
    end
  end
end
