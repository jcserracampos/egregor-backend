defmodule EgregorWeb.OracleLive do
  use EgregorWeb, :live_view

  alias Egregor.Chat
  alias Egregor.Entries
  alias Egregor.Oracle
  alias Egregor.Agents.{OracleAgent, OpenRouter}

  @impl true
  def mount(_params, _session, socket) do
    messages = Chat.list_messages()
    oracle_ctx = Oracle.get_context()
    obsessions = (oracle_ctx.obsessions || []) |> Enum.take(8)

    socket =
      socket
      |> assign(:page_title, "Oráculo")
      |> assign(:messages, messages)
      |> assign(:obsessions, obsessions)
      |> assign(:typing, false)
      |> assign(:conn_or_socket_path, "/web/oracle")

    {:ok, socket}
  end

  @impl true
  def handle_event("send-message", %{"content" => raw_content}, socket) do
    content = String.trim(raw_content)

    if content == "" or socket.assigns.typing do
      {:noreply, socket}
    else
      {:ok, _user_msg} = Chat.create_message(%{role: "user", content: content})

      messages = Chat.list_messages()

      self_pid = self()

      Task.start(fn ->
        relevant_entries =
          case OpenRouter.embed(content) do
            {:ok, embedding} -> Entries.semantic_search(embedding, 10, 0.3)
            _ -> []
          end

        oracle_context = Oracle.get_context()
        history = Chat.last_messages(5)

        case OracleAgent.respond(content, relevant_entries, oracle_context, history) do
          {:ok, response_text} ->
            entry_ids = Enum.map(relevant_entries, & &1.id)

            {:ok, _assistant_msg} =
              Chat.create_message(%{
                role: "assistant",
                content: response_text,
                entry_refs: entry_ids
              })

            send(self_pid, :oracle_done)

          {:error, _reason} ->
            send(self_pid, {:oracle_error, "o oráculo está em silêncio"})
        end
      end)

      {:noreply,
       socket
       |> assign(:messages, messages)
       |> assign(:typing, true)}
    end
  end

  @impl true
  def handle_info(:oracle_done, socket) do
    messages = Chat.list_messages()
    {:noreply, socket |> assign(:messages, messages) |> assign(:typing, false)}
  end

  @impl true
  def handle_info({:oracle_error, _msg}, socket) do
    {:noreply, assign(socket, :typing, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} conn_or_socket_path={@conn_or_socket_path}>
      <div class="oracle">
        <div class="oracle__header">
          <span class="oracle__title">O Oráculo</span>
          <%= if @obsessions != [] do %>
            <div class="oracle__obsessions">
              <%= for obs <- @obsessions do %>
                <span class="obsession-chip"><%= obs %></span>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="oracle__messages" id="oracle-messages" phx-hook="OracleScroll">
          <%= for msg <- @messages do %>
            <.chat_bubble msg={msg} />
          <% end %>

          <%= if @typing do %>
            <div class="oracle__typing">
              <div class="typing-orb"></div>
              <span class="typing-text">o oráculo contempla…</span>
            </div>
          <% end %>
        </div>

        <form phx-submit="send-message" class="oracle__input-bar">
          <textarea
            id="oracle-input"
            name="content"
            class="oracle__input"
            placeholder="Consultar o oráculo…"
            phx-hook="AutoResize"
            rows="1"
            disabled={@typing}
          ></textarea>
          <button
            type="submit"
            class="oracle__send-btn"
            disabled={@typing}
          >
            Enviar
          </button>
        </form>
      </div>
    </Layouts.app>
    """
  end

  defp chat_bubble(assigns) do
    ~H"""
    <div class={"chat-bubble chat-bubble--#{@msg.role}"}>
      <div class="chat-bubble__content">
        <%= format_content(@msg.content) %>
      </div>
      <span class="chat-bubble__time"><%= format_time(@msg.inserted_at) %></span>
    </div>
    """
  end

  defp format_content(content) do
    content
    |> String.replace(~r/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
    |> Phoenix.HTML.raw()
  end

  defp format_time(dt) do
    local = DateTime.add(dt, -3 * 3600, :second)
    hour = local.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    min = local.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{local.day}/#{local.month} #{hour}:#{min}"
  end
end
