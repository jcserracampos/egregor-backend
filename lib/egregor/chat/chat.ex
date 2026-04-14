defmodule Egregor.Chat do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Chat.ChatMessage

  def list_messages(limit \\ nil) do
    query =
      ChatMessage
      |> order_by([m], asc: m.inserted_at)

    query = if limit, do: limit(query, ^limit), else: query
    Repo.all(query)
  end

  def last_messages(n \\ 5) do
    ChatMessage
    |> order_by([m], desc: m.inserted_at)
    |> limit(^n)
    |> Repo.all()
    |> Enum.reverse()
  end

  def create_message(attrs) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end
end
