defmodule EveDmvWeb.Components.StyleGuide do
  @moduledoc """
  Style guide and documentation for EVE DMV UI components.

  This module provides a centralized reference for all UI components
  and their proper usage patterns.
  """

  use Phoenix.Component
  import EveDmvWeb.Components.ButtonComponent
  import EveDmvWeb.Components.FormComponent
  import EveDmvWeb.Components.ColorUtils
  import EveDmvWeb.Components.LoadingStateComponent

  @doc """
  Renders a comprehensive style guide showing all available components.

  ## Examples

      <.style_guide />
  """
  def style_guide(assigns) do
    assigns = assign(assigns, :page_title, "EVE DMV Style Guide")

    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8">
      <.style_guide_header />
      <.button_examples />
      <.form_examples />
      <.color_examples />
      <.loading_examples />
      <.implementation_guide />
    </div>
    """
  end

  @doc """
  Renders the style guide header.
  """
  def style_guide_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-white mb-4">EVE DMV Style Guide</h1>
      <p class="text-gray-400">
        A comprehensive reference for all UI components and their proper usage.
      </p>
    </div>
    """
  end

  @doc """
  Renders button component examples.
  """
  def button_examples(assigns) do
    ~H"""
    <section class="mb-12">
      <h2 class="text-2xl font-semibold text-white mb-6">Buttons</h2>
      
      <.button_variants />
      <.button_sizes />
      <.button_states />
    </section>
    """
  end

  defp button_variants(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-white mb-4">Button Variants</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="space-y-2">
          <h4 class="text-sm font-medium text-gray-300">Primary</h4>
          <.button variant="primary" size="md">Primary Button</.button>
        </div>
        <div class="space-y-2">
          <h4 class="text-sm font-medium text-gray-300">Secondary</h4>
          <.button variant="secondary" size="md">Secondary Button</.button>
        </div>
        <div class="space-y-2">
          <h4 class="text-sm font-medium text-gray-300">Danger</h4>
          <.button variant="danger" size="md">Danger Button</.button>
        </div>
        <div class="space-y-2">
          <h4 class="text-sm font-medium text-gray-300">Ghost</h4>
          <.button variant="ghost" size="md">Ghost Button</.button>
        </div>
      </div>
    </div>
    """
  end

  defp button_sizes(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-white mb-4">Button Sizes</h3>
      <div class="flex items-center gap-4">
        <.button variant="primary" size="sm">Small</.button>
        <.button variant="primary" size="md">Medium</.button>
        <.button variant="primary" size="lg">Large</.button>
      </div>
    </div>
    """
  end

  defp button_states(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-medium text-white mb-4">Button States</h3>
      <div class="flex items-center gap-4">
        <.button variant="primary" size="md">Normal</.button>
        <.button variant="primary" size="md" loading>Loading</.button>
        <.button variant="primary" size="md" disabled>Disabled</.button>
      </div>
    </div>
    """
  end

  @doc """
  Renders form component examples.
  """
  def form_examples(assigns) do
    ~H"""
    <section class="mb-12">
      <h2 class="text-2xl font-semibold text-white mb-6">Form Components</h2>
      
      <.input_field_examples />
      <.complete_form_field_example />
    </section>
    """
  end

  defp input_field_examples(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-white mb-4">Input Fields</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="space-y-4">
          <.input name="text" type="text" placeholder="Text input" />
          <.input name="email" type="email" placeholder="Email input" icon={:email} />
          <.input name="search" type="text" placeholder="Search input" icon={:search} />
          <.input name="disabled" type="text" placeholder="Disabled input" disabled />
        </div>
        <div class="space-y-4">
          <.textarea name="description" placeholder="Textarea input" />
          <.select name="options" options={[{"Option 1", "opt1"}, {"Option 2", "opt2"}]} placeholder="Select option" />
          <.checkbox name="agree" label="Checkbox input" />
        </div>
      </div>
    </div>
    """
  end

  defp complete_form_field_example(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-medium text-white mb-4">Complete Form Field</h3>
      <.field
        name="example"
        type="text"
        label="Example Field"
        placeholder="Enter some text"
        required
      />
    </div>
    """
  end

  @doc """
  Renders color system examples.
  """
  def color_examples(assigns) do
    ~H"""
    <section class="mb-12">
      <h2 class="text-2xl font-semibold text-white mb-6">Color System</h2>
      
      <.security_level_colors />
      <.threat_level_colors />
      <.status_pills />
    </section>
    """
  end

  defp security_level_colors(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-white mb-4">Security Level Colors</h3>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="space-y-2">
          <div class={["p-3 rounded border", security_bg_color(:highsec)]}>
            <span class={security_color(:highsec)}>Highsec</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", security_bg_color(:lowsec)]}>
            <span class={security_color(:lowsec)}>Lowsec</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", security_bg_color(:nullsec)]}>
            <span class={security_color(:nullsec)}>Nullsec</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", security_bg_color(:wormhole)]}>
            <span class={security_color(:wormhole)}>Wormhole</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp threat_level_colors(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-white mb-4">Threat Level Colors</h3>
      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:minimal)]}>
            <span class={threat_color(:minimal)}>Minimal</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:low)]}>
            <span class={threat_color(:low)}>Low</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:moderate)]}>
            <span class={threat_color(:moderate)}>Moderate</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:high)]}>
            <span class={threat_color(:high)}>High</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:very_high)]}>
            <span class={threat_color(:very_high)}>Very High</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class={["p-3 rounded border", threat_bg_color(:extreme)]}>
            <span class={threat_color(:extreme)}>Extreme</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_pills(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-medium text-white mb-4">Status Pills</h3>
      <div class="flex flex-wrap gap-2">
        <span class={pill_classes(:success)}>Success</span>
        <span class={pill_classes(:warning)}>Warning</span>
        <span class={pill_classes(:error)}>Error</span>
        <span class={pill_classes(:info)}>Info</span>
        <span class={pill_classes(:pending)}>Pending</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders loading state examples.
  """
  def loading_examples(assigns) do
    ~H"""
    <section class="mb-12">
      <h2 class="text-2xl font-semibold text-white mb-6">Loading States</h2>
      
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-lg font-medium text-white mb-4">Loading Components</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="space-y-2">
            <h4 class="text-sm font-medium text-gray-300">Small Loading</h4>
            <.loading_state size="small" message="Loading..." />
          </div>
          <div class="space-y-2">
            <h4 class="text-sm font-medium text-gray-300">Normal Loading</h4>
            <.loading_state size="normal" message="Loading data..." />
          </div>
          <div class="space-y-2">
            <h4 class="text-sm font-medium text-gray-300">Large Loading</h4>
            <.loading_state size="large" message="Processing..." />
          </div>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  Renders implementation guide and best practices.
  """
  def implementation_guide(assigns) do
    ~H"""
    <section class="mb-12">
      <h2 class="text-2xl font-semibold text-white mb-6">Implementation Guide</h2>
      
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-lg font-medium text-white mb-4">Best Practices</h3>
        <div class="space-y-4 text-gray-300">
          <div>
            <h4 class="font-medium text-white mb-2">1. Use Standardized Components</h4>
            <p>Always use the standardized <code class="bg-gray-700 px-2 py-1 rounded">.button</code>, <code class="bg-gray-700 px-2 py-1 rounded">.input</code>, and other components instead of custom HTML.</p>
          </div>
          <div>
            <h4 class="font-medium text-white mb-2">2. Consistent Color Usage</h4>
            <p>Use the <code class="bg-gray-700 px-2 py-1 rounded">ColorUtils</code> functions for consistent color mapping across security levels, threat levels, and status indicators.</p>
          </div>
          <div>
            <h4 class="font-medium text-white mb-2">3. Loading States</h4>
            <p>Use <code class="bg-gray-700 px-2 py-1 rounded">.loading_state</code> for full-page loading and <code class="bg-gray-700 px-2 py-1 rounded">loading={true}</code> on buttons for inline loading.</p>
          </div>
          <div>
            <h4 class="font-medium text-white mb-2">4. Form Validation</h4>
            <p>Use <code class="bg-gray-700 px-2 py-1 rounded">.field</code> components for complete form fields with built-in label and error handling.</p>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
