defmodule Egregor.Filaments do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Filaments.Filament
  alias Egregor.Entries.Entry

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  def list_filaments(opts \\ []) do
    limit = opts[:limit] || 20

    from(f in Filament,
      order_by: [desc: f.last_linked_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_filament!(id), do: Repo.get!(Filament, id)

  def get_filament_with_entries(id) do
    filament = Repo.get!(Filament, id)

    entries =
      from(e in Entry,
        where: e.filament_id == ^id,
        order_by: [asc: e.filament_position, asc: e.inserted_at]
      )
      |> Repo.all()

    Map.put(filament, :entries, entries)
  end

  def list_resurgence_pending do
    from(e in Entry,
      where: e.resurgence_pending == true and is_nil(e.filament_id),
      order_by: [desc: e.resurgence_marked_at]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Resurgence marking
  # ---------------------------------------------------------------------------

  def mark_resurgence(%Entry{} = entry) do
    entry
    |> Entry.resurgence_changeset(%{
      resurgence_pending: true,
      resurgence_marked_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def unmark_resurgence(%Entry{} = entry) do
    entry
    |> Entry.resurgence_changeset(%{resurgence_pending: false, resurgence_marked_at: nil})
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Candidate search
  # Returns top-5 [{entry, similarity}] nearest to the given entry's embedding,
  # excluding itself and entries already in the same filament.
  # Includes transmuted entries (historical continuity).
  # No time window, no similarity cutoff.
  # ---------------------------------------------------------------------------

  def resurgence_candidates(entry, limit \\ 5)

  def resurgence_candidates(%Entry{embedding: nil}, _limit), do: []

  def resurgence_candidates(%Entry{id: entry_id, embedding: embedding, filament_id: filament_id}, limit) do
    vector = embedding

    from(e in Entry,
      where: not is_nil(e.embedding),
      where: e.id != ^entry_id,
      order_by: fragment("embedding <=> ?", ^vector),
      limit: ^limit,
      select: %{
        entry: e,
        similarity: fragment("1 - (embedding <=> ?)", ^vector)
      }
    )
    |> exclude_same_filament(filament_id)
    |> Repo.all()
  end

  defp exclude_same_filament(query, nil), do: query

  defp exclude_same_filament(query, filament_id) do
    where(query, [e], is_nil(e.filament_id) or e.filament_id != ^filament_id)
  end

  # ---------------------------------------------------------------------------
  # Link operations
  # ---------------------------------------------------------------------------

  @doc """
  Links two entries into a filament.
  - Both without filament: creates new filament
  - One has filament, other doesn't: appends to existing filament
  - Both in same filament: no-op (idempotent)
  - Both in different filaments: {:error, :filament_conflict, [fid_a, fid_b]}
  """
  def link_entries(%Entry{} = entry_a, %Entry{} = entry_b) do
    cond do
      # Same filament — idempotent
      not is_nil(entry_a.filament_id) and entry_a.filament_id == entry_b.filament_id ->
        {:ok, get_filament_with_entries(entry_a.filament_id)}

      # Conflict — different filaments
      not is_nil(entry_a.filament_id) and not is_nil(entry_b.filament_id) ->
        {:error, :filament_conflict, [entry_a.filament_id, entry_b.filament_id]}

      # A has filament, B doesn't — add B to A's filament
      not is_nil(entry_a.filament_id) ->
        add_entry(get_filament!(entry_a.filament_id), entry_b)

      # B has filament, A doesn't — add A to B's filament
      not is_nil(entry_b.filament_id) ->
        add_entry(get_filament!(entry_b.filament_id), entry_a)

      # Both without filament — create new one
      true ->
        create_filament_with_entries([entry_a, entry_b])
    end
  end

  @doc """
  Adds a single entry to an existing filament.
  Returns {:error, :filament_conflict, [existing_id]} if entry belongs to another filament.
  """
  def add_entry(%Filament{} = filament, %Entry{} = entry) do
    cond do
      entry.filament_id == filament.id ->
        {:ok, get_filament_with_entries(filament.id)}

      not is_nil(entry.filament_id) ->
        {:error, :filament_conflict, [entry.filament_id]}

      true ->
        Repo.transaction(fn ->
          next_position = next_filament_position(filament.id)

          {:ok, updated_entry} =
            entry
            |> Entry.filament_link_changeset(%{
              filament_id: filament.id,
              filament_position: next_position,
              resurgence_pending: false
            })
            |> Repo.update()

          {:ok, updated_filament} =
            filament
            |> Filament.changeset(%{
              entry_count: filament.entry_count + 1,
              last_linked_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })
            |> Repo.update()

          centroid = compute_centroid(updated_filament.id)
          {:ok, _} = updated_filament |> Filament.centroid_changeset(centroid) |> Repo.update()

          _ = updated_entry
          get_filament_with_entries(filament.id)
        end)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp create_filament_with_entries(entries) do
    sorted = Enum.sort_by(entries, & &1.inserted_at, DateTime)

    Repo.transaction(fn ->
      {:ok, filament} =
        %Filament{}
        |> Filament.changeset(%{
          entry_count: length(sorted),
          last_linked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert()

      sorted
      |> Enum.with_index(1)
      |> Enum.each(fn {entry, pos} ->
        {:ok, _} =
          entry
          |> Entry.filament_link_changeset(%{
            filament_id: filament.id,
            filament_position: pos,
            resurgence_pending: false
          })
          |> Repo.update()
      end)

      centroid = compute_centroid(filament.id)
      {:ok, _} = filament |> Filament.centroid_changeset(centroid) |> Repo.update()

      get_filament_with_entries(filament.id)
    end)
  end

  defp next_filament_position(filament_id) do
    result =
      from(e in Entry,
        where: e.filament_id == ^filament_id,
        select: max(e.filament_position)
      )
      |> Repo.one()

    (result || 0) + 1
  end

  # Computes L2-normalized centroid of all entry embeddings in the filament.
  # Returns a Pgvector struct or nil if no embeddings exist.
  defp compute_centroid(filament_id) do
    embeddings =
      from(e in Entry,
        where: e.filament_id == ^filament_id and not is_nil(e.embedding),
        select: e.embedding
      )
      |> Repo.all()
      |> Enum.map(&Pgvector.to_list/1)

    case embeddings do
      [] ->
        nil

      vecs ->
        n = length(vecs)
        dim = length(hd(vecs))

        mean =
          Enum.reduce(vecs, List.duplicate(0.0, dim), fn vec, acc ->
            Enum.zip_with(acc, vec, &(&1 + &2))
          end)
          |> Enum.map(&(&1 / n))

        norm = :math.sqrt(Enum.sum(Enum.map(mean, &(&1 * &1))))

        normalized =
          if norm > 0.0 do
            Enum.map(mean, &(&1 / norm))
          else
            mean
          end

        Pgvector.new(normalized)
    end
  end
end
