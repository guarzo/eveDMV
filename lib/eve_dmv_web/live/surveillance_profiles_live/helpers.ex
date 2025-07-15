defmodule EveDmvWeb.SurveillanceProfilesLive.Helpers do
  @moduledoc """
  Helper functions for the Surveillance Profiles LiveView.
  """

  use Phoenix.Component

  alias EveDmvWeb.Helpers.TimeFormatter

  def format_filter_type(type) do
    case type do
      :character_watch -> "Character"
      :corporation_watch -> "Corporation"
      :alliance_watch -> "Alliance"
      :system_watch -> "System"
      :ship_type_watch -> "Ship Type"
      :chain_watch -> "Chain Awareness"
      :isk_value -> "ISK Value"
      :participant_count -> "Participant Count"
      _ -> "Unknown"
    end
  end

  def render_filter_inputs(condition, index) do
    case condition.type do
      :character_watch ->
        render_id_list_input(condition, index, :character_ids, "Character IDs (comma-separated)")

      :corporation_watch ->
        render_id_list_input(
          condition,
          index,
          :corporation_ids,
          "Corporation IDs (comma-separated)"
        )

      :alliance_watch ->
        render_id_list_input(condition, index, :alliance_ids, "Alliance IDs (comma-separated)")

      :system_watch ->
        render_id_list_input(condition, index, :system_ids, "System IDs (comma-separated)")

      :ship_type_watch ->
        render_id_list_input(condition, index, :ship_type_ids, "Ship Type IDs (comma-separated)")

      :chain_watch ->
        render_chain_filter_inputs(condition, index)

      :isk_value ->
        render_isk_value_inputs(condition, index)

      :participant_count ->
        render_participant_count_inputs(condition, index)

      _ ->
        assigns = %{message: "Unknown filter type"}

        ~H"""
        <div class="text-red-500 text-sm"><%= @message %></div>
        """
    end
  end

  defp render_id_list_input(condition, index, field, placeholder) do
    value = Enum.join(Map.get(condition, field, []), ", ")

    assigns = %{
      index: index,
      field: field,
      value: value,
      placeholder: placeholder,
      input_id: "filter_#{index}_#{field}"
    }

    ~H"""
    <div class="relative" phx-hook="AutocompleteInput" id={"#{@input_id}_container"} data-index={@index} data-field={@field}>
      <input
        id={@input_id}
        type="text"
        phx-blur="update_filter_field"
        phx-keyup="search_autocomplete"
        phx-value-index={@index}
        phx-value-field={@field}
        phx-debounce="300"
        value={@value}
        placeholder={@placeholder}
        class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100 placeholder-gray-400"
        autocomplete="off"
      />
      <div id={"#{@input_id}_suggestions"} class="absolute z-10 w-full bg-gray-700 border border-gray-600 rounded-md mt-1 max-h-40 overflow-y-auto hidden">
        <!-- Autocomplete suggestions will be populated here -->
      </div>
    </div>
    """
  end

  defp render_chain_filter_inputs(condition, index) do
    map_id = Map.get(condition, :map_id, "")
    filter_type = Map.get(condition, :chain_filter_type, :in_chain)
    max_jumps = Map.get(condition, :max_jumps, 1)

    assigns = %{
      index: index,
      map_id: map_id,
      filter_type: filter_type,
      max_jumps: max_jumps
    }

    ~H"""
    <div class="space-y-3">
      <div>
        <label class="block text-xs text-gray-400 mb-1">Map ID</label>
        <input
          type="text"
          phx-blur="update_filter_field"
          phx-value-index={@index}
          phx-value-field="map_id"
          value={@map_id}
          placeholder="Map slug or ID"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100 placeholder-gray-400"
        />
      </div>
      
      <div>
        <label class="block text-xs text-gray-400 mb-1">Filter Type</label>
        <select
          phx-change="update_filter_field"
          phx-value-index={@index}
          phx-value-field="chain_filter_type"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100"
        >
          <option value="in_chain" selected={@filter_type == :in_chain}>In Chain</option>
          <option value="within_jumps" selected={@filter_type == :within_jumps}>Within X Jumps</option>
          <option value="chain_inhabitant" selected={@filter_type == :chain_inhabitant}>Chain Inhabitant</option>
          <option value="entering_chain" selected={@filter_type == :entering_chain}>Entering Chain</option>
        </select>
      </div>
      
      <%= if @filter_type == :within_jumps do %>
        <div>
          <label class="block text-xs text-gray-400 mb-1">Max Jumps</label>
          <input
            type="number"
            phx-blur="update_filter_field"
            phx-value-index={@index}
            phx-value-field="max_jumps"
            value={@max_jumps}
            min="1"
            max="10"
            class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100"
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp render_isk_value_inputs(condition, index) do
    operator = Map.get(condition, :operator, :greater_than)
    value = Map.get(condition, :value, 1_000_000_000)

    assigns = %{
      index: index,
      operator: operator,
      value: value
    }

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-xs text-gray-400 mb-1">Operator</label>
        <select
          phx-change="update_filter_field"
          phx-value-index={@index}
          phx-value-field="operator"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100"
        >
          <option value="greater_than" selected={@operator == :greater_than}>Greater Than</option>
          <option value="less_than" selected={@operator == :less_than}>Less Than</option>
          <option value="equals" selected={@operator == :equals}>Equals</option>
        </select>
      </div>
      
      <div>
        <label class="block text-xs text-gray-400 mb-1">ISK Value</label>
        <input
          type="number"
          phx-blur="update_filter_field"
          phx-value-index={@index}
          phx-value-field="value"
          value={@value}
          placeholder="1000000000"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100 placeholder-gray-400"
        />
      </div>
    </div>
    """
  end

  defp render_participant_count_inputs(condition, index) do
    operator = Map.get(condition, :operator, :greater_than)
    value = Map.get(condition, :value, 5)

    assigns = %{
      index: index,
      operator: operator,
      value: value
    }

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-xs text-gray-400 mb-1">Operator</label>
        <select
          phx-change="update_filter_field"
          phx-value-index={@index}
          phx-value-field="operator"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100"
        >
          <option value="greater_than" selected={@operator == :greater_than}>Greater Than</option>
          <option value="less_than" selected={@operator == :less_than}>Less Than</option>
          <option value="equals" selected={@operator == :equals}>Equals</option>
        </select>
      </div>
      
      <div>
        <label class="block text-xs text-gray-400 mb-1">Participant Count</label>
        <input
          type="number"
          phx-blur="update_filter_field"
          phx-value-index={@index}
          phx-value-field="value"
          value={@value}
          min="1"
          class="w-full px-3 py-2 bg-gray-600 border border-gray-500 rounded-md text-sm text-gray-100"
        />
      </div>
    </div>
    """
  end

  def format_filter_summary(criteria) do
    conditions = Map.get(criteria, :conditions, [])
    logic_op = Map.get(criteria, :logic_operator, :and)

    if Enum.empty?(conditions) do
      "No filters configured"
    else
      count = Enum.count(conditions)
      logic_text = if logic_op == :and, do: "ALL", else: "ANY"
      "#{count} filter(s) with #{logic_text} logic"
    end
  end

  def format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 ->
        "#{Float.round(value / 1_000_000_000, 1)}B"

      value >= 1_000_000 ->
        "#{Float.round(value / 1_000_000, 1)}M"

      value >= 1_000 ->
        "#{Float.round(value / 1_000, 1)}K"

      true ->
        "#{value}"
    end
  end

  def format_isk(_), do: "0"

  def format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> TimeFormatter.format_relative_time(dt)
      _ -> timestamp
    end
  end

  def format_timestamp(%DateTime{} = dt), do: TimeFormatter.format_relative_time(dt)
  def format_timestamp(%NaiveDateTime{} = ndt), do: format_naive_datetime(ndt)
  def format_timestamp(_), do: "Unknown"

  defp format_naive_datetime(ndt) do
    case DateTime.from_naive(ndt, "Etc/UTC") do
      {:ok, dt} -> TimeFormatter.format_relative_time(dt)
      _ -> "Unknown"
    end
  end
end
