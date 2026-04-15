defmodule Egregor.Jobs.DetectConvergenceJob do
  use Oban.Worker, queue: :batch, max_attempts: 2

  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Entries.Entry
  alias Egregor.Filaments.Filament
  alias Egregor.Agents.Convergent

  @similarity_threshold 0.75
  @days_window 7
  # Max pairs fetched from DB before union-find clustering
  @max_pairs 50
  # Max cluster size passed to the LLM (avoids token explosion)
  @max_cluster_size 5

  @impl Oban.Worker
  def perform(_job) do
    pairs = fetch_semantic_pairs()

    pairs
    |> build_clusters()
    |> Enum.each(&process_cluster/1)

    :ok
  end

  # Each "node" in pairs is either {:entry, %Entry{}} or {:filament, filament_id}.
  # The build_clusters/process_cluster pipeline uses the raw id string as the
  # union-find key. process_cluster expands filament nodes into their entries before
  # calling the LLM (Convergent only sees Entry structs).
  #
  # We keep the old entry-only path as well so existing tests aren't affected.

  # ---------------------------------------------------------------------------
  # Cluster detection: union-find (path compression) over unit pairs.
  # A "unit" is either an Entry struct or a filament_id string (prefixed "f:").
  # ---------------------------------------------------------------------------

  # Returns a list of clusters, where each cluster is a list of Entry structs.
  defp build_clusters(pairs) do
    parent = build_union_find(pairs)

    unit_by_id =
      pairs
      |> Enum.flat_map(fn {u1_id, u1, u2_id, u2, _sim} ->
        [{u1_id, u1}, {u2_id, u2}]
      end)
      |> Map.new()

    groups =
      unit_by_id
      |> Map.keys()
      |> Enum.group_by(fn id -> find_root(parent, id) end)

    groups
    |> Map.values()
    |> Enum.filter(fn ids -> length(ids) >= 2 end)
    |> Enum.map(fn ids ->
      ids
      |> Enum.take(@max_cluster_size)
      |> Enum.flat_map(fn id ->
        case Map.fetch!(unit_by_id, id) do
          %Entry{} = entry -> [entry]
          {:filament, filament_id} -> expand_filament(filament_id)
        end
      end)
    end)
  end

  defp build_union_find(pairs) do
    initial =
      pairs
      |> Enum.flat_map(fn {id1, _, id2, _, _} -> [id1, id2] end)
      |> Enum.uniq()
      |> Map.new(&{&1, &1})

    Enum.reduce(pairs, initial, fn {id1, _, id2, _, _sim}, parent ->
      root1 = find_root(parent, id1)
      root2 = find_root(parent, id2)

      if root1 == root2 do
        parent
      else
        Map.put(parent, root1, root2)
      end
    end)
  end

  defp find_root(parent, id) do
    case Map.fetch!(parent, id) do
      ^id -> id
      parent_id -> find_root(parent, parent_id)
    end
  end

  # Expand filament into its constituent entries for LLM analysis.
  defp expand_filament(filament_id) do
    Egregor.Filaments.get_filament_with_entries(filament_id).entries
  rescue
    Ecto.NoResultsError -> []
  end

  # ---------------------------------------------------------------------------

  defp process_cluster(entries) do
    case Convergent.detect(entries) do
      {:ok, nil} ->
        :ok

      {:ok, %{entry_ids: ids, message: msg, pattern_type: ptype}} ->
        %Egregor.Convergences.Convergence{}
        |> Egregor.Convergences.Convergence.changeset(%{
          entry_ids: ids,
          message: msg,
          pattern_type: ptype
        })
        |> Repo.insert()

      {:error, _reason} ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # pgvector-native query over "units":
  #   - orphan entries (no filament, not transmuted, with embedding, within window)
  #   - filaments with centroid (active within window)
  #
  # Each row in the result is {unit_id, unit_value, unit_id2, unit_value2, similarity}
  # where unit_value is either an Entry struct or {:filament, id}.
  #
  # Category-exclusion filter applies only between two entries (filaments are
  # inherently cross-category). Uses raw SQL via fragment for the UNION query.
  # ---------------------------------------------------------------------------

  defp fetch_semantic_pairs do
    cutoff = DateTime.add(DateTime.utc_now(), -@days_window * 24 * 3600, :second)

    entry_pairs = fetch_entry_entry_pairs(cutoff)
    filament_pairs = fetch_filament_pairs(cutoff)

    (entry_pairs ++ filament_pairs)
    |> Enum.sort_by(fn {_, _, _, _, sim} -> -sim end)
    |> Enum.take(@max_pairs)
  end

  defp fetch_entry_entry_pairs(cutoff) do
    Repo.all(
      from e1 in Entry,
        join: e2 in Entry,
        on: e1.id < e2.id,
        where:
          is_nil(e1.filament_id) and
            is_nil(e2.filament_id) and
            e1.inserted_at > ^cutoff and
            e2.inserted_at > ^cutoff and
            not is_nil(e1.embedding) and
            not is_nil(e2.embedding) and
            is_nil(e1.transmuted_at) and
            is_nil(e2.transmuted_at),
        where: fragment("NOT (? && ?)", e1.categories, e2.categories),
        where:
          fragment(
            "1 - (? <=> ?) > ?",
            e1.embedding,
            e2.embedding,
            ^@similarity_threshold
          ),
        order_by: fragment("? <=> ?", e1.embedding, e2.embedding),
        limit: ^@max_pairs,
        select: {
          e1.id,
          e1,
          e2.id,
          e2,
          fragment("1 - (? <=> ?)", e1.embedding, e2.embedding)
        }
    )
    |> Enum.map(fn {id1, e1, id2, e2, sim} -> {id1, e1, id2, e2, sim} end)
  end

  defp fetch_filament_pairs(cutoff) do
    # Orphan entries near a filament centroid.
    # Key for the filament node is "filament:<uuid>" — consistent so that multiple
    # entries near the same filament get unioned into one cluster.
    Repo.all(
      from e in Entry,
        join: f in Filament,
        on: true,
        where:
          is_nil(e.filament_id) and
            e.inserted_at > ^cutoff and
            not is_nil(e.embedding) and
            is_nil(e.transmuted_at) and
            not is_nil(f.centroid_embedding) and
            f.last_linked_at > ^cutoff,
        where:
          fragment(
            "1 - (? <=> ?) > ?",
            e.embedding,
            f.centroid_embedding,
            ^@similarity_threshold
          ),
        order_by: fragment("? <=> ?", e.embedding, f.centroid_embedding),
        limit: ^div(@max_pairs, 2),
        select: {
          e.id,
          e,
          f.id,
          fragment("1 - (? <=> ?)", e.embedding, f.centroid_embedding)
        }
    )
    |> Enum.map(fn {eid, entry, fid, sim} ->
      filament_key = "filament:#{fid}"
      {eid, entry, filament_key, {:filament, fid}, sim}
    end)
  end
end
