defmodule EgregorWeb.ChatController do
  use EgregorWeb, :controller

  alias Egregor.Chat
  alias Egregor.Entries
  alias Egregor.Oracle
  alias Egregor.Agents.{OracleAgent, OpenRouter}

  def messages(conn, _params) do
    messages = Chat.list_messages()
    json(conn, %{data: Enum.map(messages, &serialize/1)})
  end

  def create(conn, %{"content" => content}) do
    # Save user message
    {:ok, _user_msg} = Chat.create_message(%{role: "user", content: content})

    # Get embedding for semantic search
    relevant_entries =
      case OpenRouter.embed(content) do
        {:ok, embedding} -> Entries.semantic_search(embedding, 10, 0.3)
        _ -> []
      end

    # Load oracle context
    oracle_context = Oracle.get_context()

    # Load recent chat history (last 5)
    history = Chat.last_messages(5)

    # Call the Oracle
    case OracleAgent.respond(content, relevant_entries, oracle_context, history) do
      {:ok, response_text} ->
        entry_ids = Enum.map(relevant_entries, & &1.id)

        {:ok, assistant_msg} =
          Chat.create_message(%{
            role: "assistant",
            content: response_text,
            entry_refs: entry_ids
          })

        json(conn, %{data: serialize(assistant_msg)})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Oracle unavailable", reason: inspect(reason)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "content is required"})
  end

  defp serialize(msg) do
    %{
      id: msg.id,
      role: msg.role,
      content: msg.content,
      entry_refs: msg.entry_refs,
      inserted_at: msg.inserted_at
    }
  end
end
