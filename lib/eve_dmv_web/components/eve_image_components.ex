defmodule EveDmvWeb.EveImageComponents do
  @moduledoc """
  Components for displaying EVE Online images including character portraits,
  corporation logos, alliance logos, and ship renders.
  """
  use Phoenix.Component

  @doc """
  Renders a character portrait with fallback.
  """
  attr(:character_id, :integer, required: true)
  attr(:name, :string, default: "Character")
  attr(:size, :integer, default: 64)
  attr(:class, :string, default: "")

  def character_portrait(assigns) do
    ~H"""
    <img
      src={"https://images.evetech.net/characters/#{@character_id}/portrait"}
      alt={@name}
      width={@size}
      height={@size}
      class={["rounded-full", @class]}
      loading="lazy"
      onerror={"this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Crect width=%22100%22 height=%22100%22 fill=%22%23374151%22/%3E%3Ctext x=%2250%22 y=%2250%22 text-anchor=%22middle%22 dy=%22.3em%22 fill=%22%23fff%22 font-size=%2240%22%3E?%3C/text%3E%3C/svg%3E'"}
    />
    """
  end

  @doc """
  Renders a corporation logo.
  """
  attr(:corporation_id, :integer, required: true)
  attr(:name, :string, default: "Corporation")
  attr(:size, :integer, default: 32)
  attr(:class, :string, default: "")

  def corporation_logo(assigns) do
    ~H"""
    <img
      src={"https://images.evetech.net/corporations/#{@corporation_id}/logo"}
      alt={@name}
      width={@size}
      height={@size}
      class={["rounded", @class]}
      loading="lazy"
      onerror={"this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Crect width=%22100%22 height=%22100%22 fill=%22%234B5563%22/%3E%3C/svg%3E'"}
    />
    """
  end

  @doc """
  Renders an alliance logo.
  """
  attr(:alliance_id, :integer, required: true)
  attr(:name, :string, default: "Alliance")
  attr(:size, :integer, default: 32)
  attr(:class, :string, default: "")

  def alliance_logo(assigns) do
    ~H"""
    <img
      src={"https://images.evetech.net/alliances/#{@alliance_id}/logo"}
      alt={@name}
      width={@size}
      height={@size}
      class={["rounded", @class]}
      loading="lazy"
      onerror={"this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Crect width=%22100%22 height=%22100%22 fill=%22%235B6371%22/%3E%3C/svg%3E'"}
    />
    """
  end

  @doc """
  Renders a ship render/icon.
  """
  attr(:type_id, :integer, required: true)
  attr(:name, :string, default: "Ship")
  attr(:size, :integer, default: 64)
  attr(:render, :boolean, default: false)
  attr(:class, :string, default: "")

  def ship_image(assigns) do
    # Use render for larger images, icon for smaller
    assigns = assign(assigns, :image_type, if(assigns.render, do: "render", else: "icon"))

    ~H"""
    <img
      src={"https://images.evetech.net/types/#{@type_id}/#{@image_type}"}
      alt={@name}
      width={@size}
      height={@size}
      class={@class}
      loading="lazy"
      onerror={"this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Crect width=%22100%22 height=%22100%22 fill=%22%23374151%22/%3E%3Ctext x=%2250%22 y=%2250%22 text-anchor=%22middle%22 dy=%22.3em%22 fill=%22%23fff%22 font-size=%2214%22%3EShip%3C/text%3E%3C/svg%3E'"}
    />
    """
  end

  @doc """
  Renders a combined character/corp/alliance display.
  """
  attr(:character_id, :integer, required: true)
  attr(:character_name, :string, required: true)
  attr(:corporation_id, :integer, default: nil)
  attr(:corporation_name, :string, default: nil)
  attr(:alliance_id, :integer, default: nil)
  attr(:alliance_name, :string, default: nil)
  attr(:class, :string, default: "")
  # sm, md, lg
  attr(:size, :string, default: "md")

  def character_identity(assigns) do
    sizes =
      case assigns.size do
        "sm" -> %{portrait: 32, logo: 24}
        "lg" -> %{portrait: 96, logo: 48}
        _ -> %{portrait: 64, logo: 32}
      end

    assigns = assign(assigns, :sizes, sizes)

    ~H"""
    <div class={["flex items-center gap-3", @class]}>
      <.character_portrait 
        character_id={@character_id} 
        name={@character_name}
        size={@sizes.portrait}
      />
      <div class="flex-1">
        <div class="font-medium text-white">{@character_name}</div>
        <div class="flex items-center gap-2 text-sm text-gray-400">
          <%= if @corporation_id do %>
            <.corporation_logo 
              corporation_id={@corporation_id}
              name={@corporation_name}
              size={@sizes.logo}
            />
            <span>{@corporation_name}</span>
          <% end %>
          <%= if @alliance_id do %>
            <span class="text-gray-600">|</span>
            <.alliance_logo 
              alliance_id={@alliance_id}
              name={@alliance_name}
              size={@sizes.logo}
            />
            <span>{@alliance_name}</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a pilot card with stats.
  """
  attr(:pilot, :map, required: true)
  attr(:class, :string, default: "")

  def pilot_card(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg p-4 hover:bg-gray-700/50 transition-colors", @class]}>
      <div class="flex items-start justify-between mb-3">
        <.character_identity
          character_id={@pilot["character_id"]}
          character_name={@pilot["character_name"]}
          corporation_id={@pilot["corporation_id"]}
          corporation_name={@pilot["corporation_name"]}
          alliance_id={@pilot["alliance_id"]}
          alliance_name={@pilot["alliance_name"]}
          size="sm"
        />
        <div class="text-right text-sm">
          <div class="text-gray-400">Together</div>
          <div class="font-medium">{@pilot["times_together"]}x</div>
        </div>
      </div>
      
      <div class="grid grid-cols-3 gap-2 text-sm">
        <div class="text-center">
          <div class="text-gray-400">Kills</div>
          <div class="font-medium text-green-400">{@pilot["kills"] || 0}</div>
        </div>
        <div class="text-center">
          <div class="text-gray-400">Deaths</div>
          <div class="font-medium text-red-400">{@pilot["deaths"] || 0}</div>
        </div>
        <div class="text-center">
          <div class="text-gray-400">K/D</div>
          <div class="font-medium">{format_kd_ratio(@pilot)}</div>
        </div>
      </div>
      
      <%= if @pilot["preferred_ship_name"] do %>
        <div class="mt-3 flex items-center gap-2 text-sm">
          <.ship_image 
            type_id={@pilot["preferred_ship_id"]}
            name={@pilot["preferred_ship_name"]}
            size={24}
          />
          <span class="text-gray-400">Flies</span>
          <span class="font-medium">{@pilot["preferred_ship_name"]}</span>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_kd_ratio(pilot) do
    kills = pilot["kills"] || 0
    deaths = pilot["deaths"] || 0

    cond do
      deaths == 0 and kills > 0 -> "∞"
      deaths == 0 -> "0.0"
      true -> Float.round(kills / deaths, 1) |> to_string()
    end
  end
end
