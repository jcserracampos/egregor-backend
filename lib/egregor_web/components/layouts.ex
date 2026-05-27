defmodule EgregorWeb.Layouts do
  @moduledoc """
  Root and app layouts for the web interface.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: EgregorWeb.Endpoint,
    router: EgregorWeb.Router,
    statics: EgregorWeb.static_paths()

  # Root layout is embedded and used via put_root_layout in the router pipeline
  embed_templates "layouts/root*"

  @doc """
  The app layout: sidebar navigation + main content slot.
  """
  attr :flash, :map, required: true
  attr :conn_or_socket_path, :string, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="layout" id="app-layout">
      <nav class="sidebar">
        <div class="sidebar__top">
          <div class="sidebar__logo">
            <span class="sidebar__glyph">⬡</span>
            <span class="sidebar__name">Egrégor</span>
          </div>
        </div>

        <ul class="sidebar__nav">
          <li class={"sidebar__item#{if String.starts_with?(@conn_or_socket_path, "/web/capture"), do: " sidebar__item--active", else: ""}"}>
            <a href={~p"/web/capture"} class="sidebar__link">
              <span class="sidebar__icon">✦</span>
              <span class="sidebar__label">Captura</span>
            </a>
          </li>
          <li class={"sidebar__item#{if @conn_or_socket_path == "/web", do: " sidebar__item--active", else: ""}"}>
            <a href={~p"/web"} class="sidebar__link">
              <span class="sidebar__icon">◉</span>
              <span class="sidebar__label">Firmamento</span>
            </a>
          </li>
          <li class={"sidebar__item#{if String.starts_with?(@conn_or_socket_path, "/web/oracle"), do: " sidebar__item--active", else: ""}"}>
            <a href={~p"/web/oracle"} class="sidebar__link">
              <span class="sidebar__icon">☽</span>
              <span class="sidebar__label">Oráculo</span>
            </a>
          </li>
          <li class={"sidebar__item#{if String.starts_with?(@conn_or_socket_path, "/web/review"), do: " sidebar__item--active", else: ""}"}>
            <a href={~p"/web/review"} class="sidebar__link">
              <span class="sidebar__icon">⊞</span>
              <span class="sidebar__label">Sabbath</span>
            </a>
          </li>
        </ul>

        <div class="sidebar__bottom">
          <a href={~p"/web/logout"} data-method="delete" class="sidebar__logout">
            <span class="sidebar__icon">⏻</span>
            <span class="sidebar__label">Sair</span>
          </a>
        </div>
      </nav>

      <main class="main-content">
        <.flash_group flash={@flash} />
        <%= render_slot(@inner_block) %>
      </main>
    </div>
    """
  end

  @doc """
  Renders flash messages.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="flash-group" aria-live="polite">
      <%= for {kind, msg} <- @flash do %>
        <div class={"flash flash--#{kind}"}>
          <span><%= msg %></span>
        </div>
      <% end %>
    </div>
    """
  end
end
