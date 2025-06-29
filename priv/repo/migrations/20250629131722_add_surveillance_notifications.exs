defmodule EveDmv.Repo.Migrations.AddSurveillanceNotifications do
  @moduledoc """
  Creates the surveillance_notifications table for storing persistent notifications
  about surveillance profile matches and other system events.
  """
  
  use Ecto.Migration

  def up do
    create table(:surveillance_notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :notification_type, :text, null: false, default: "profile_match"
      add :profile_id, :binary_id, null: true
      add :killmail_id, :bigint, null: true
      add :title, :text, null: false
      add :message, :text, null: false
      add :data, :map, null: true
      add :is_read, :boolean, null: false, default: false
      add :read_at, :utc_datetime, null: true
      add :priority, :text, null: false, default: "normal"
      
      timestamps(type: :utc_datetime)
    end

    # Create indexes for performance
    create index(:surveillance_notifications, [:user_id, :inserted_at], name: :notifications_user_time_idx)
    create index(:surveillance_notifications, [:is_read], name: :notifications_read_idx)
    create index(:surveillance_notifications, [:notification_type], name: :notifications_type_idx)
    create index(:surveillance_notifications, [:profile_id], name: :notifications_profile_idx)
    create index(:surveillance_notifications, [:priority], name: :notifications_priority_idx)
    create index(:surveillance_notifications, [:killmail_id], name: :notifications_killmail_idx)

    # Add foreign key constraints
    create constraint(:surveillance_notifications, :valid_notification_type, 
      check: "notification_type IN ('profile_match', 'system_alert', 'profile_created', 'profile_deleted')")
    
    create constraint(:surveillance_notifications, :valid_priority,
      check: "priority IN ('low', 'normal', 'high', 'urgent')")
  end

  def down do
    drop table(:surveillance_notifications)
  end
end