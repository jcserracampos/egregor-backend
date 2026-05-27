defmodule EgregorWeb.CaptureLive do
  use EgregorWeb, :live_view

  alias Egregor.Entries

  @impl true
  def mount(_params, _session, socket) do
    recent = Entries.list_recent(5)

    socket =
      socket
      |> assign(:page_title, "Captura")
      |> assign(:text, "")
      |> assign(:recent_entries, recent)
      |> assign(:submitting, false)
      |> assign(:recording, false)
      |> assign(:recording_seconds, 0)
      |> assign(:audio_uploading, false)
      |> assign(:conn_or_socket_path, "/web/capture")

    {:ok, socket}
  end

  @impl true
  def handle_event("update-text", %{"value" => value}, socket) do
    {:noreply, assign(socket, :text, value)}
  end

  @impl true
  def handle_event("submit-text", _params, socket) do
    text = String.trim(socket.assigns.text)

    if text == "" do
      {:noreply, socket}
    else
      case Entries.create_entry(%{raw_text: text}) do
        {:ok, _entry} ->
          recent = Entries.list_recent(5)

          {:noreply,
           socket
           |> assign(:text, "")
           |> assign(:recent_entries, recent)
           |> assign(:submitting, false)}

        {:error, _changeset} ->
          {:noreply, assign(socket, :submitting, false)}
      end
    end
  end

  @impl true
  def handle_event("toggle-record", _params, socket) do
    if socket.assigns.recording do
      push_event(socket, "stop-recording", %{})
      {:noreply, assign(socket, :recording, false)}
    else
      push_event(socket, "start-recording", %{})
      {:noreply, assign(socket, :recording, true)}
    end
  end

  @impl true
  def handle_event("recording-started", _params, socket) do
    {:noreply, assign(socket, recording: true, recording_seconds: 0)}
  end

  @impl true
  def handle_event("recording-tick", %{"seconds" => s}, socket) do
    {:noreply, assign(socket, :recording_seconds, s)}
  end

  @impl true
  def handle_event("recording-error", %{"reason" => reason}, socket) do
    {:noreply,
     socket
     |> assign(recording: false, recording_seconds: 0)
     |> put_flash(:error, "Microfone indisponível: #{reason}")}
  end

  @impl true
  def handle_event("audio-uploaded", %{"entry" => _entry_data}, socket) do
    recent = Entries.list_recent(5)

    {:noreply,
     socket
     |> assign(audio_uploading: false, recording: false, recording_seconds: 0)
     |> assign(:recent_entries, recent)}
  end

  @impl true
  def handle_event("audio-error", %{"reason" => reason}, socket) do
    {:noreply,
     socket
     |> assign(audio_uploading: false, recording: false)
     |> put_flash(:error, "Erro no upload de áudio: #{reason}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} conn_or_socket_path={@conn_or_socket_path}>
      <div class="capture">
        <div class="capture__header">
          <div>
            <div class="capture__title">A Boca do Caos</div>
            <div class="capture__subtitle">Solve et Coagula</div>
          </div>
        </div>

        <div class="capture__input-area">
          <textarea
            id="capture-textarea"
            class="capture__textarea"
            placeholder="O que atravessa o limiar…"
            phx-keyup="update-text"
            phx-hook="AutoResize"
            value={@text}
            rows="5"
          ><%= @text %></textarea>

          <div class="capture__actions">
            <button
              class="capture__btn capture__btn--primary"
              phx-click="submit-text"
              disabled={@submitting or @text == ""}
            >
              ✦ Lançar
            </button>

            <button
              id="audio-recorder"
              phx-hook="AudioRecorder"
              class={"capture__btn capture__btn--record#{if @recording, do: " capture__btn--recording", else: ""}"}
              phx-click="toggle-record"
            >
              <%= if @recording do %>
                ⏹ Parar
              <% else %>
                ⏺ Áudio
              <% end %>
            </button>

            <%= if @recording do %>
              <span class="capture__audio-timer"><%= format_seconds(@recording_seconds) %></span>
            <% end %>

            <%= if @audio_uploading do %>
              <span class="entry-tile__flag--processing">enviando áudio…</span>
            <% end %>
          </div>
        </div>

        <div class="entries-section">
          <div class="entries-section__title">Recentes</div>
          <div class="entries-list">
            <%= for entry <- @recent_entries do %>
              <.entry_tile entry={entry} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_seconds(s) do
    m = div(s, 60)
    sec = rem(s, 60)
    "#{String.pad_leading(Integer.to_string(m), 2, "0")}:#{String.pad_leading(Integer.to_string(sec), 2, "0")}"
  end

  defp entry_tile(assigns) do
    ~H"""
    <div class={"entry-tile#{if @entry.transmuted_at, do: " entry-tile--transmuted", else: ""}"}>
      <div class="entry-tile__text">
        <%= if @entry.transcription do %>
          <%= @entry.transcription %>
        <% else %>
          <%= @entry.raw_text %>
        <% end %>
      </div>
      <div class="entry-tile__meta">
        <span class="entry-tile__time"><%= format_time(@entry.inserted_at) %></span>
        <%= if @entry.categories != [] do %>
          <div class="entry-tile__categories">
            <%= for cat <- @entry.categories do %>
              <span class="category-chip" style={"color: var(--gold); border-color: rgba(201,170,130,0.3)"}><%= cat %></span>
            <% end %>
          </div>
        <% else %>
          <span class="entry-tile__flag--processing">classificando…</span>
        <% end %>
        <%= if @entry.is_intention do %>
          <span class="entry-tile__flag--intention">✦</span>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(dt) do
    local = DateTime.add(dt, -3 * 3600, :second)
    hour = local.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    min = local.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{local.day}/#{local.month} #{hour}:#{min}"
  end
end
