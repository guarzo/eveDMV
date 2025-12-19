defmodule EveDmv.Repo.Migrations.AddOnDeleteCascadeToForeignKeys do
  @moduledoc """
  Adds ON DELETE CASCADE behavior to foreign keys for proper data integrity.

  This migration updates foreign keys to cascade deletes when parent records
  are deleted, preventing orphaned records in child tables.

  Changes:
  - surveillance_profile_matches.profile_id -> CASCADE (delete matches when profile deleted)
  - surveillance_notifications.user_id -> CASCADE (delete notifications when user deleted)
  - surveillance_notifications.profile_id -> SET NULL (keep notification but clear profile ref)
  """

  use Ecto.Migration

  def up do
    # Update surveillance_profile_matches.profile_id to CASCADE
    execute """
    ALTER TABLE surveillance_profile_matches
    DROP CONSTRAINT IF EXISTS surveillance_profile_matches_profile_id_fkey
    """

    execute """
    ALTER TABLE surveillance_profile_matches
    ADD CONSTRAINT surveillance_profile_matches_profile_id_fkey
    FOREIGN KEY (profile_id) REFERENCES surveillance_profiles(id) ON DELETE CASCADE
    """

    # Update surveillance_notifications.user_id to CASCADE
    execute """
    ALTER TABLE surveillance_notifications
    DROP CONSTRAINT IF EXISTS surveillance_notifications_user_id_fkey
    """

    execute """
    ALTER TABLE surveillance_notifications
    ADD CONSTRAINT surveillance_notifications_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    """

    # Update surveillance_notifications.profile_id to SET NULL
    # (Keep notification history even if profile is deleted)
    execute """
    ALTER TABLE surveillance_notifications
    DROP CONSTRAINT IF EXISTS surveillance_notifications_profile_id_fkey
    """

    execute """
    ALTER TABLE surveillance_notifications
    ADD CONSTRAINT surveillance_notifications_profile_id_fkey
    FOREIGN KEY (profile_id) REFERENCES surveillance_profiles(id) ON DELETE SET NULL
    """
  end

  def down do
    # Revert to original constraints without ON DELETE behavior

    # surveillance_profile_matches.profile_id
    execute """
    ALTER TABLE surveillance_profile_matches
    DROP CONSTRAINT IF EXISTS surveillance_profile_matches_profile_id_fkey
    """

    execute """
    ALTER TABLE surveillance_profile_matches
    ADD CONSTRAINT surveillance_profile_matches_profile_id_fkey
    FOREIGN KEY (profile_id) REFERENCES surveillance_profiles(id)
    """

    # surveillance_notifications.user_id
    execute """
    ALTER TABLE surveillance_notifications
    DROP CONSTRAINT IF EXISTS surveillance_notifications_user_id_fkey
    """

    execute """
    ALTER TABLE surveillance_notifications
    ADD CONSTRAINT surveillance_notifications_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id)
    """

    # surveillance_notifications.profile_id
    execute """
    ALTER TABLE surveillance_notifications
    DROP CONSTRAINT IF EXISTS surveillance_notifications_profile_id_fkey
    """

    execute """
    ALTER TABLE surveillance_notifications
    ADD CONSTRAINT surveillance_notifications_profile_id_fkey
    FOREIGN KEY (profile_id) REFERENCES surveillance_profiles(id)
    """
  end
end
