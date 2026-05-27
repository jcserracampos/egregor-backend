defmodule EgregorWeb.DashboardLive do
  use EgregorWeb, :live_view

  alias Egregor.Categories
  alias Egregor.Convergences
  alias Egregor.Time

  @impl true
  def mount(_params, _session, socket) do
    categories = Categories.list_active()
    convergence = Convergences.latest_unseen()
    phrase = fetch_phrase()

    socket =
      socket
      |> assign(:page_title, "Firmamento")
      |> assign(:categories, categories)
      |> assign(:convergence, convergence)
      |> assign(:phrase, phrase)
      |> assign(:conn_or_socket_path, "/web")

    socket =
      if connected?(socket) do
        push_event(socket, "update-balls", %{categories: serialize_categories(categories)})
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} conn_or_socket_path={@conn_or_socket_path}>
      <div class="dashboard">
        <div class="dashboard__header">
          <span class="dashboard__title">Firmamento</span>
          <span class="dashboard__meta">
            <%= length(@categories) %> categorias ·
            <%= Enum.sum(Enum.map(@categories, & &1.entry_count)) %> entradas
          </span>
        </div>

        <div class="dashboard__canvas-wrap" id="balls-wrap" phx-hook="FloatingBalls">
          <canvas id="balls-canvas"></canvas>
        </div>

        <div class="dashboard__strip">
          <%= if @convergence do %>
            <span class="dashboard__strip-convergence">◈ <%= @convergence.pattern_type %> · <%= @convergence.message %></span>
          <% end %>
          <%= if @phrase do %>
            <span class="dashboard__strip-phrase"><%= @phrase %></span>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp fetch_phrase do
    cache_key = Time.hourly_cache_key()

    case :ets.lookup(:oracle_phrase_cache, cache_key) do
      [{^cache_key, cached}] ->
        cached

      [] ->
        "Solve et Coagula."
    end
  end

  defp serialize_categories(categories) do
    Enum.map(categories, fn c ->
      %{
        id: c.id,
        name: c.name,
        color: c.color,
        glow_color: c.glow_color,
        entry_count: c.entry_count
      }
    end)
  end
end
