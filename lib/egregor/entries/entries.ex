defmodule Egregor.Entries do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Entries.Entry
  alias Egregor.Jobs.{GenerateEmbeddingJob, CategorizeEntryJob, GenerateSigilJob, CheckMilestonesJob}

  def list_entries(opts \\ []) do
    base = from(e in Entry, order_by: [desc: e.inserted_at])

    base
    |> maybe_filter_category(opts[:category])
    |> maybe_filter_intention(opts[:intention])
    |> maybe_limit(opts[:limit])
    |> Repo.all()
  end

  def list_recent(limit \\ 5) do
    Entry
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_entry!(id), do: Repo.get!(Entry, id)

  def create_entry(attrs) do
    result =
      %Entry{}
      |> Entry.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, entry} ->
        enqueue_processing_jobs(entry)
        {:ok, entry}

      error ->
        error
    end
  end

  def update_entry(%Entry{} = entry, attrs) do
    result =
      entry
      |> Entry.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        if Map.has_key?(attrs, :raw_text) or Map.has_key?(attrs, "raw_text") do
          enqueue_processing_jobs(updated)
        end

        if intention_changed?(entry, updated) do
          if updated.is_intention do
            %{"entry_id" => updated.id}
            |> GenerateSigilJob.new()
            |> Oban.insert()
          end
        end

        {:ok, updated}

      error ->
        error
    end
  end

  def update_embedding(%Entry{} = entry, embedding) do
    entry
    |> Entry.embedding_changeset(embedding)
    |> Repo.update()
  end

  def update_categorization(%Entry{} = entry, attrs) do
    entry
    |> Entry.categorize_changeset(attrs)
    |> Repo.update()
  end

  def semantic_search(embedding, limit \\ 10, threshold \\ 0.3) do
    vector = Pgvector.new(embedding)

    from(e in Entry,
      where: not is_nil(e.embedding),
      order_by: fragment("embedding <=> ?", ^vector),
      limit: ^limit,
      select: %{
        entry: e,
        similarity: fragment("1 - (embedding <=> ?)", ^vector)
      }
    )
    |> Repo.all()
    |> Enum.filter(fn %{similarity: sim} -> sim >= threshold end)
    |> Enum.map(& &1.entry)
  end

  def count_entries do
    Repo.aggregate(Entry, :count, :id)
  end

  def last_intention do
    Entry
    |> where([e], e.is_intention == true)
    |> order_by([e], desc: e.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp enqueue_processing_jobs(%Entry{id: id}) do
    {:ok, _} =
      %{"entry_id" => id}
      |> GenerateEmbeddingJob.new()
      |> Oban.insert()

    {:ok, _} =
      %{"entry_id" => id}
      |> CategorizeEntryJob.new()
      |> Oban.insert()

    {:ok, _} =
      %{"entry_id" => id}
      |> CheckMilestonesJob.new()
      |> Oban.insert()
  end

  def transmute_entry(%Entry{} = entry, note \\ nil) do
    entry
    |> Entry.transmute_changeset(%{
      transmuted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      transmutation_note: note
    })
    |> Repo.update()
  end

  defp intention_changed?(old, new) do
    old.is_intention != new.is_intention
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category) do
    where(query, [e], ^category in e.categories)
  end

  defp maybe_filter_intention(query, true), do: where(query, [e], e.is_intention == true)
  defp maybe_filter_intention(query, _), do: query

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)
end
