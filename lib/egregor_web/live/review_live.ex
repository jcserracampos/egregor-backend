defmodule EgregorWeb.ReviewLive do
  use EgregorWeb, :live_view

  alias Egregor.Entries
  alias Egregor.Agents.OpenRouter
  alias Egregor.Time

  @impl true
  def mount(_params, _session, socket) do
    active = Entries.list_entries([])
    transmuted = Enum.filter(active, & &1.transmuted_at)
    active = Enum.reject(active, & &1.transmuted_at)
    resurgences = Entries.list_entries(resurgence_pending: true)
    ritual_mode = Time.ritual_mode?()

    socket =
      socket
      |> assign(:page_title, "Sabbath")
      |> assign(:active_entries, active)
      |> assign(:transmuted_entries, transmuted)
      |> assign(:resurgence_entries, resurgences)
      |> assign(:search_query, "")
      |> assign(:search_results, nil)
      |> assign(:searching, false)
      |> assign(:sediment_open, false)
      |> assign(:ritual_mode, ritual_mode)
      |> assign(:editing_id, nil)
      |> assign(:edit_text, "")
      |> assign(:conn_or_socket_path, "/web/review")

    {:ok, socket}
  end

  @impl true
  def handle_event("search-change", %{"query" => query}, socket) do
    if String.trim(query) == "" do
      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_results, nil)
       |> assign(:searching, false)}
    else
      send(self(), {:do_search, query})
      {:noreply, assign(socket, search_query: query, searching: true)}
    end
  end

  @impl true
  def handle_event("clear-search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, nil)
     |> assign(:searching, false)}
  end

  @impl true
  def handle_event("toggle-sediment", _params, socket) do
    {:noreply, update(socket, :sediment_open, &(!&1))}
  end

  @impl true
  def handle_event("start-edit", %{"id" => id}, socket) do
    entry = find_entry(socket, id)
    text = entry.transcription || entry.raw_text || ""
    {:noreply, socket |> assign(:editing_id, id) |> assign(:edit_text, text)}
  end

  @impl true
  def handle_event("cancel-edit", _params, socket) do
    {:noreply, socket |> assign(:editing_id, nil) |> assign(:edit_text, "")}
  end

  @impl true
  def handle_event("save-edit", %{"_entry_id" => id, "text" => text}, socket) do
    entry = find_entry(socket, id)

    case Entries.update_entry(entry, %{raw_text: String.trim(text)}) do
      {:ok, _updated} ->
        active = Entries.list_entries([])
        transmuted = Enum.filter(active, & &1.transmuted_at)
        active = Enum.reject(active, & &1.transmuted_at)

        {:noreply,
         socket
         |> assign(:active_entries, active)
         |> assign(:transmuted_entries, transmuted)
         |> assign(:editing_id, nil)
         |> assign(:edit_text, "")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-intention", %{"id" => id}, socket) do
    entry = find_entry(socket, id)

    case Entries.update_entry(entry, %{is_intention: !entry.is_intention}) do
      {:ok, _} -> {:noreply, reload_entries(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-shadow", %{"id" => id}, socket) do
    entry = find_entry(socket, id)

    case Entries.update_entry(entry, %{is_shadow: !entry.is_shadow}) do
      {:ok, _} -> {:noreply, reload_entries(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("transmute", %{"id" => id}, socket) do
    entry = find_entry(socket, id)

    case Entries.transmute_entry(entry) do
      {:ok, _} -> {:noreply, reload_entries(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set-urgency", %{"id" => id, "urgency" => urgency}, socket) do
    entry = find_entry(socket, id)

    case Entries.update_entry(entry, %{urgency: urgency}) do
      {:ok, _} -> {:noreply, reload_entries(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:do_search, query}, socket) do
    results =
      case OpenRouter.embed(query) do
        {:ok, embedding} -> Entries.semantic_search(embedding, 20, 0.25)
        _ -> []
      end

    {:noreply, socket |> assign(:search_results, results) |> assign(:searching, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} conn_or_socket_path={@conn_or_socket_path}>
      <div class={"review#{if @ritual_mode, do: " ritual-mode", else: ""}"} id="review-root" phx-hook="RitualMode" data-ritual={if @ritual_mode, do: "true", else: "false"}>
        <div class="review__header">
          <div class="review__title-row">
            <span class="review__title">O Sabbath</span>
          </div>
          <div class="review__search">
            <input
              type="text"
              class="review__search-input"
              placeholder="Busca semântica…"
              value={@search_query}
              phx-change="search-change"
              phx-debounce="400"
              name="query"
            />
          </div>
        </div>

        <div class="review__body">
          <%= if @search_results do %>
            <div class="review__section">
              <div class="review__section-title">
                Resultados da busca
                <span class="review__section-count"><%= length(@search_results) %></span>
              </div>
              <%= if @searching do %>
                <div class="shimmer" style="height:60px"></div>
              <% end %>
              <%= for entry <- @search_results do %>
                <.entry_edit_tile entry={entry} editing_id={@editing_id} edit_text={@edit_text} />
              <% end %>
              <%= if @search_results == [] and not @searching do %>
                <span style="font-size:13px;color:var(--muted);font-style:italic">Nenhum resultado.</span>
              <% end %>
            </div>
          <% else %>
            <%= if @resurgence_entries != [] do %>
              <div class="review__section">
                <div class="review__section-title">
                  Resurgências
                  <span class="review__section-count"><%= length(@resurgence_entries) %></span>
                </div>
                <%= for entry <- @resurgence_entries do %>
                  <div class="resurgence-card">
                    <span class="resurgence-card__label">◈ ressurgindo</span>
                    <div class="resurgence-card__text"><%= entry.transcription || entry.raw_text %></div>
                    <div class="resurgence-card__action">
                      <button class="entry-action-btn entry-action-btn--gold" phx-click="toggle-intention" phx-value-id={entry.id}>✦ intenção</button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="review__section">
              <div class="review__section-title">
                Entradas Ativas
                <span class="review__section-count"><%= length(@active_entries) %></span>
              </div>
              <%= for entry <- @active_entries do %>
                <.entry_edit_tile entry={entry} editing_id={@editing_id} edit_text={@edit_text} />
              <% end %>
            </div>

            <div class="review__section">
              <div class="review__section-title">
                Sedimento Alquímico
                <span class="review__section-count"><%= length(@transmuted_entries) %></span>
              </div>
              <%= if @transmuted_entries != [] do %>
                <button class="sediment-toggle" phx-click="toggle-sediment">
                  <%= if @sediment_open, do: "▲ ocultar", else: "▼ mostrar #{length(@transmuted_entries)} transmutadas" %>
                </button>
                <%= if @sediment_open do %>
                  <%= for entry <- @transmuted_entries do %>
                    <div class="entry-tile entry-tile--transmuted">
                      <div class="entry-tile__text"><%= entry.transcription || entry.raw_text %></div>
                      <div class="entry-tile__meta">
                        <span class="entry-tile__time"><%= format_time(entry.transmuted_at) %></span>
                        <%= if entry.transmutation_note do %>
                          <span style="font-size:11px;color:var(--muted);font-style:italic"><%= entry.transmutation_note %></span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              <% else %>
                <span style="font-size:13px;color:var(--muted);font-style:italic">Nenhuma entrada transmutada ainda.</span>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp entry_edit_tile(assigns) do
    is_editing = assigns.editing_id == to_string(assigns.entry.id)
    assigns = assign(assigns, :is_editing, is_editing)

    ~H"""
    <div class="entry-edit-tile">
      <div class="entry-edit-tile__top">
        <%= if @is_editing do %>
          <form phx-submit="save-edit" style="flex:1;display:flex;gap:8px;align-items:flex-start">
            <input type="hidden" name="_entry_id" value={@entry.id} />
            <textarea
              name="text"
              class="entry-edit-tile__text-area"
              style="border:1px solid var(--gold-dim);border-radius:var(--radius);padding:4px 8px;min-height:60px;width:100%"
              phx-hook="AutoResize"
              id={"edit-#{@entry.id}"}
            ><%= @edit_text %></textarea>
            <div style="display:flex;flex-direction:column;gap:4px;flex-shrink:0">
              <button type="submit" class="entry-action-btn entry-action-btn--gold">salvar</button>
              <button type="button" class="entry-action-btn" phx-click="cancel-edit">cancelar</button>
            </div>
          </form>
        <% else %>
          <div class="entry-tile__text" style="flex:1">
            <%= @entry.transcription || @entry.raw_text %>
          </div>
          <div class="entry-edit-tile__actions">
            <button class="entry-action-btn" phx-click="start-edit" phx-value-id={@entry.id}>editar</button>
            <button
              class={"entry-action-btn entry-action-btn--gold#{if @entry.is_intention, do: " active", else: ""}"}
              phx-click="toggle-intention"
              phx-value-id={@entry.id}
              title="Marcar intenção"
            >✦</button>
            <button
              class="entry-action-btn entry-action-btn--rose"
              phx-click="toggle-shadow"
              phx-value-id={@entry.id}
              title="Mover para sombra"
            >◎</button>
            <button
              class="entry-action-btn entry-action-btn--burgundy"
              phx-click="transmute"
              phx-value-id={@entry.id}
              title="Transmutar"
              data-confirm="Transmutar esta entrada?"
            >⚗</button>
          </div>
        <% end %>
      </div>
      <div class="entry-edit-tile__meta">
        <span class="entry-tile__time"><%= format_time(@entry.inserted_at) %></span>
        <span class={"entry-tile__urgency urgency--#{@entry.urgency}"}></span>
        <select
          phx-change="set-urgency"
          phx-value-id={@entry.id}
          style="background:transparent;border:none;color:var(--muted);font-size:11px;cursor:pointer;outline:none"
        >
          <option value="low" selected={@entry.urgency == "low"}>baixa</option>
          <option value="med" selected={@entry.urgency == "med"}>média</option>
          <option value="high" selected={@entry.urgency == "high"}>alta</option>
        </select>
        <%= if @entry.categories != [] do %>
          <div class="entry-tile__categories">
            <%= for cat <- @entry.categories do %>
              <span class="category-chip" style={"color: var(--gold); border-color: rgba(201,170,130,0.25)"}><%= cat %></span>
            <% end %>
          </div>
        <% else %>
          <span class="entry-tile__flag--processing">classificando…</span>
        <% end %>
        <%= if @entry.is_intention do %>
          <span class="entry-tile__flag--intention" title="Intenção">✦</span>
        <% end %>
        <%= if @entry.is_shadow do %>
          <span class="entry-tile__flag--shadow" title="Sombra">◎</span>
        <% end %>
      </div>
    </div>
    """
  end

  defp find_entry(socket, id) do
    all =
      socket.assigns.active_entries ++
        socket.assigns.transmuted_entries ++
        socket.assigns.resurgence_entries ++
        (socket.assigns.search_results || [])

    Enum.find(all, fn e -> to_string(e.id) == id end)
  end

  defp reload_entries(socket) do
    all = Entries.list_entries([])
    transmuted = Enum.filter(all, & &1.transmuted_at)
    active = Enum.reject(all, & &1.transmuted_at)
    resurgences = Entries.list_entries(resurgence_pending: true)

    socket
    |> assign(:active_entries, active)
    |> assign(:transmuted_entries, transmuted)
    |> assign(:resurgence_entries, resurgences)
  end

  defp format_time(nil), do: ""

  defp format_time(dt) do
    local = DateTime.add(dt, -3 * 3600, :second)
    hour = local.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    min = local.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{local.day}/#{local.month} #{hour}:#{min}"
  end
end
