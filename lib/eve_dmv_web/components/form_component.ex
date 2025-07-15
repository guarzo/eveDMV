defmodule EveDmvWeb.Components.FormComponent do
  @moduledoc """
  Reusable form components with consistent styling.

  Provides standardized form inputs, labels, and validation states.
  """

  use Phoenix.Component
  import EveDmvWeb.Components.Icons

  @doc """
  Renders a text input with consistent styling.

  ## Examples

      <.input name="email" type="email" placeholder="Enter your email" />
      <.input name="password" type="password" required />
      <.input name="search" type="text" placeholder="Search..." icon={:search} />
  """
  attr(:name, :string, required: true)
  attr(:type, :string, default: "text")
  attr(:placeholder, :string, default: "")
  attr(:value, :string, default: "")
  attr(:required, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:icon, :atom, default: nil, doc: "Optional icon: :search, :email, :user, etc.")
  attr(:rest, :global, include: ~w(phx-change phx-submit phx-blur phx-focus autocomplete))

  def input(assigns) do
    ~H"""
    <div class="relative">
      <%= if @icon do %>
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <.icon type={@icon} />
        </div>
      <% end %>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        required={@required}
        disabled={@disabled}
        class={[
          "w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400",
          "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "disabled:opacity-50 disabled:cursor-not-allowed",
          "transition-colors duration-200",
          if(@icon, do: "pl-10", else: ""),
          @class
        ]}
        {@rest}
      />
    </div>
    """
  end

  @doc """
  Renders a textarea with consistent styling.

  ## Examples

      <.textarea name="description" placeholder="Enter description..." rows="4" />
      <.textarea name="notes" value={@notes} required />
  """
  attr(:name, :string, required: true)
  attr(:placeholder, :string, default: "")
  attr(:value, :string, default: "")
  attr(:rows, :string, default: "3")
  attr(:required, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(phx-change phx-submit phx-blur phx-focus))

  def textarea(assigns) do
    ~H"""
    <textarea
      name={@name}
      placeholder={@placeholder}
      rows={@rows}
      required={@required}
      disabled={@disabled}
      class={[
        "w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400",
        "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        "transition-colors duration-200 resize-vertical",
        @class
      ]}
      {@rest}
    ><%= @value %></textarea>
    """
  end

  @doc """
  Renders a select dropdown with consistent styling.

  ## Examples

      <.select name="category" options={[{"Option 1", "value1"}, {"Option 2", "value2"}]} />
      <.select name="status" options={@status_options} value={@current_status} />
  """
  attr(:name, :string, required: true)
  attr(:options, :list, required: true, doc: "List of {label, value} tuples")
  attr(:value, :string, default: "")
  attr(:placeholder, :string, default: "Select an option")
  attr(:required, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(phx-change phx-submit))

  def select(assigns) do
    ~H"""
    <select
      name={@name}
      required={@required}
      disabled={@disabled}
      class={[
        "w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white",
        "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        "transition-colors duration-200",
        @class
      ]}
      {@rest}
    >
      <%= if @placeholder != "" do %>
        <option value="" disabled selected={@value == ""}>
          <%= @placeholder %>
        </option>
      <% end %>
      <%= for {label, value} <- @options do %>
        <option value={value} selected={@value == value}>
          <%= label %>
        </option>
      <% end %>
    </select>
    """
  end

  @doc """
  Renders a checkbox with consistent styling.

  ## Examples

      <.checkbox name="agree" label="I agree to the terms" />
      <.checkbox name="notifications" label="Enable notifications" checked />
  """
  attr(:name, :string, required: true)
  attr(:label, :string, required: true)
  attr(:checked, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(phx-change phx-click value))

  def checkbox(assigns) do
    ~H"""
    <div class={["flex items-center", @class]}>
      <input
        type="checkbox"
        name={@name}
        checked={@checked}
        disabled={@disabled}
        class={[
          "w-4 h-4 bg-gray-700 border-gray-600 rounded text-blue-600",
          "focus:ring-blue-500 focus:ring-2 focus:ring-offset-0",
          "disabled:opacity-50 disabled:cursor-not-allowed"
        ]}
        {@rest}
      />
      <label class="ml-2 text-sm text-gray-300">
        <%= @label %>
      </label>
    </div>
    """
  end

  @doc """
  Renders a form label with consistent styling.

  ## Examples

      <.label for="email" required>Email Address</.label>
      <.label for="description">Description</.label>
  """
  attr(:for, :string, required: true)
  attr(:required, :boolean, default: false)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label
      for={@for}
      class={[
        "block text-sm font-medium text-gray-200 mb-2",
        @class
      ]}
    >
      <%= render_slot(@inner_block) %>
      <%= if @required do %>
        <span class="text-red-400 ml-1">*</span>
      <% end %>
    </label>
    """
  end

  @doc """
  Renders form validation errors.

  ## Examples

      <.error_message errors={@errors} field={:email} />
  """
  attr(:errors, :list, default: [])
  attr(:field, :atom, required: true)
  attr(:class, :string, default: "")

  def error_message(assigns) do
    ~H"""
    <%= for error <- Keyword.get_values(@errors, @field) do %>
      <div class={["text-red-400 text-sm mt-1", @class]}>
        <%= error %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a form field group with label, input, and error handling.

  ## Examples

      <.field name="email" type="email" label="Email Address" required />
      <.field name="password" type="password" label="Password" errors={@errors} />
  """
  attr(:name, :string, required: true)

  attr(:field, :atom,
    doc: "The field atom for error message lookup - defaults to atom version of name"
  )

  attr(:type, :string, default: "text")
  attr(:label, :string, required: true)
  attr(:value, :string, default: "")
  attr(:placeholder, :string, default: "")
  attr(:required, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:errors, :list, default: [])
  attr(:class, :string, default: "")
  attr(:rest, :global)

  def field(assigns) do
    # Use the provided field atom or safely convert name to atom
    assigns = assign_field_atom(assigns)

    ~H"""
    <div class={["space-y-2", @class]}>
      <.label for={@name} required={@required}>
        <%= @label %>
      </.label>
      <.input
        name={@name}
        type={@type}
        value={@value}
        placeholder={@placeholder}
        required={@required}
        disabled={@disabled}
        {@rest}
      />
      <.error_message errors={@errors} field={@field_atom} />
    </div>
    """
  end

  defp assign_field_atom(assigns) do
    field_atom =
      case Map.get(assigns, :field) do
        nil ->
          # Try to convert name to existing atom safely
          try do
            String.to_existing_atom(assigns.name)
          rescue
            ArgumentError ->
              # If atom doesn't exist, use a safe default
              # This avoids creating new atoms at runtime
              :form_field
          end

        atom when is_atom(atom) ->
          atom
      end

    Map.put(assigns, :field_atom, field_atom)
  end
end
