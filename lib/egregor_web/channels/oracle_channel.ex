defmodule EgregorWeb.OracleChannel do
  use Phoenix.Channel

  alias Egregor.Chat
  alias Egregor.Entries
  alias Egregor.Oracle
  alias Egregor.Agents.{OracleAgent, OpenRouter}

  def join("oracle:lobby", _payload, socket) do
    Phoenix.PubSub.subscribe(Egregor.PubSub, "oracle:responses:#{socket.id || "default"}")
    {:ok, socket}
  end

  def handle_in("query", %{"content" => content}, socket) do
    {:ok, _user_msg} = Chat.create_message(%{role: "user", content: content})

    push(socket, "typing", %{})

    channel_pid = self()

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

          {:ok, assistant_msg} =
            Chat.create_message(%{
              role: "assistant",
              content: response_text,
              entry_refs: entry_ids
            })

          send(channel_pid, {:oracle_response, assistant_msg})

        {:error, reason} ->
          send(channel_pid, {:oracle_error, inspect(reason)})
      end
    end)

    {:noreply, socket}
  end

  def handle_info({:oracle_response, msg}, socket) do
    push(socket, "response", serialize_msg(msg))
    {:noreply, socket}
  end

  def handle_info({:oracle_error, reason}, socket) do
    push(socket, "error", %{message: "o oráculo está em silêncio", reason: reason})
    {:noreply, socket}
  end

  defp serialize_msg(msg) do
    %{
      id: msg.id,
      role: msg.role,
      content: msg.content,
      entry_refs: msg.entry_refs || [],
      inserted_at: msg.inserted_at
    }
  end
end
