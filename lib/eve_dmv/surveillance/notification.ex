defmodule EveDmv.Surveillance.Notification do
  @moduledoc """
  Notification resource for surveillance profile matches and other system events.
  
  Stores notifications for users about surveillance profile matches, allowing
  for persistent notification history and user notification preferences.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("surveillance_notifications")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:user_id, :created_at], name: "notifications_user_time_idx")
      index([:is_read], name: "notifications_read_idx")
      index([:notification_type], name: "notifications_type_idx")
      index([:profile_id], name: "notifications_profile_idx")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:mark_read, action: :mark_read)
    define(:unread_for_user, args: [:user_id])
    define(:recent_for_user, args: [:user_id, :hours])
  end

  # Attributes
  attributes do
    # Primary key
    uuid_primary_key(:id)

    # User the notification belongs to
    attribute :user_id, :uuid do
      allow_nil?(false)
      description("User ID this notification belongs to")
    end

    # Notification type
    attribute :notification_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:profile_match, :system_alert, :profile_created, :profile_deleted])
      default(:profile_match)
      description("Type of notification")
    end

    # Profile that triggered this notification (if applicable)
    attribute :profile_id, :uuid do
      allow_nil?(true)
      description("Surveillance profile ID that triggered this notification")
    end

    # Killmail that triggered this notification (if applicable)
    attribute :killmail_id, :integer do
      allow_nil?(true)
      description("Killmail ID that triggered this notification")
    end

    # Notification content
    attribute :title, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Notification title")
    end

    attribute :message, :string do
      allow_nil?(false)
      constraints(max_length: 1000)
      description("Notification message")
    end

    # Notification metadata
    attribute :data, :map do
      allow_nil?(true)
      description("Additional notification data (JSON)")
    end

    # Notification status
    attribute :is_read, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether the notification has been read")
    end

    attribute :read_at, :utc_datetime do
      allow_nil?(true)
      description("When the notification was read")
    end

    # Priority level
    attribute :priority, :atom do
      allow_nil?(false)
      constraints(one_of: [:low, :normal, :high, :urgent])
      default(:normal)
      description("Notification priority level")
    end

    # Automatic timestamps
    timestamps()
  end

  # Relationships
  relationships do
    belongs_to :profile, EveDmv.Surveillance.Profile do
      source_attribute(:profile_id)
      destination_attribute(:id)
      description("Surveillance profile that triggered this notification")
    end

    belongs_to :user, EveDmv.Users.User do
      source_attribute(:user_id)
      destination_attribute(:id)
      description("User this notification belongs to")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create action
    create :create do
      primary?(true)
      description("Create a notification")

      accept([
        :user_id,
        :notification_type,
        :profile_id,
        :killmail_id,
        :title,
        :message,
        :data,
        :priority
      ])
    end

    # Mark notification as read
    update :mark_read do
      description("Mark a notification as read")
      
      accept([])
      
      change(set_attribute(:is_read, true))
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end

    # Bulk mark as read for user
    update :mark_all_read do
      description("Mark all notifications as read for a user")
      
      argument :user_id, :uuid do
        allow_nil?(false)
        description("User ID to mark notifications for")
      end

      filter(expr(user_id == ^arg(:user_id) and is_read == false))
      
      change(set_attribute(:is_read, true))
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end

    # Read actions for queries
    read :unread_for_user do
      description("Get unread notifications for a user")

      argument :user_id, :uuid do
        allow_nil?(false)
        description("User ID to get notifications for")
      end

      filter(expr(user_id == ^arg(:user_id) and is_read == false))
      prepare(build(sort: [created_at: :desc]))
    end

    read :recent_for_user do
      description("Get recent notifications for a user")

      argument :user_id, :uuid do
        allow_nil?(false)
        description("User ID to get notifications for")
      end

      argument :hours, :integer do
        allow_nil?(false)
        default(24)
        description("Hours to look back")
      end

      filter(expr(user_id == ^arg(:user_id) and created_at >= ago(^arg(:hours), :hour)))
      prepare(build(sort: [created_at: :desc], limit: 50))
    end

    read :by_profile do
      description("Get notifications for a specific profile")

      argument :profile_id, :uuid do
        allow_nil?(false)
        description("Profile ID to get notifications for")
      end

      filter(expr(profile_id == ^arg(:profile_id)))
      prepare(build(sort: [created_at: :desc]))
    end

    read :by_type do
      description("Get notifications by type")

      argument :notification_type, :atom do
        allow_nil?(false)
        description("Notification type to filter by")
      end

      argument :user_id, :uuid do
        allow_nil?(true)
        description("Optional user ID to filter by")
      end

      filter(expr(notification_type == ^arg(:notification_type)))
      prepare(build(sort: [created_at: :desc]))
    end
  end

  # Calculations
  calculations do
    calculate :age_in_minutes, :integer do
      description("Age of notification in minutes")
      
      calculation(fn records, _context ->
        now = DateTime.utc_now()
        
        Enum.map(records, fn record ->
          DateTime.diff(now, record.created_at, :minute)
        end)
      end)
    end

    calculate :is_urgent, :boolean, expr(priority == :urgent) do
      description("Whether this notification is urgent")
    end
  end

  # Authorization policies
  policies do
    # Users can only read their own notifications
    policy action_type(:read) do
      authorize_if(expr(user_id == ^actor(:id)))
    end

    # Only authenticated users can create notifications (system-level)
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_present())
    end
  end
end