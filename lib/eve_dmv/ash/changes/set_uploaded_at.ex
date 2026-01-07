defmodule EveDmv.Ash.Changes.SetUploadedAt do
  @moduledoc """
  Ash change that sets the uploaded_at attribute to the current UTC timestamp.

  This provides a standardized way to set upload timestamps across resources
  that track when content was uploaded.

  ## Usage

  Add the `uploaded_at` attribute to your resource:

      attributes do
        attribute :uploaded_at, :utc_datetime_usec, allow_nil?: false
      end

  Use this change in create or update actions:

      actions do
        create :create do
          change {EveDmv.Ash.Changes.SetUploadedAt, []}
        end

        create :upload do
          change {EveDmv.Ash.Changes.SetUploadedAt, []}
        end
      end

  ## Options

  - `:field` - The attribute to set (default: `:uploaded_at`)
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    field = Keyword.get(opts, :field, :uploaded_at)
    Ash.Changeset.change_attribute(changeset, field, DateTime.utc_now())
  end
end
