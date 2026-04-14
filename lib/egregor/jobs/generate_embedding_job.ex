defmodule Egregor.Jobs.GenerateEmbeddingJob do
  use Oban.Worker, queue: :embeddings, max_attempts: 3

  alias Egregor.Agents.OpenRouter
  alias Egregor.Repo
  alias Egregor.Entries.Entry

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"entry_id" => entry_id}}) do
    entry = Repo.get!(Entry, entry_id)

    text = entry.transcription || entry.raw_text

    case OpenRouter.embed(text) do
      {:ok, embedding} ->
        entry
        |> Entry.embedding_changeset(Pgvector.new(embedding))
        |> Repo.update()

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
