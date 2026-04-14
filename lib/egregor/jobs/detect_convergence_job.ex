defmodule Egregor.Jobs.DetectConvergenceJob do
  use Oban.Worker, queue: :batch, max_attempts: 2

  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Entries.Entry
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

  # ---------------------------------------------------------------------------
  # Cluster detection: union-find (path compression) over entry pairs
  # ---------------------------------------------------------------------------

  # Returns a list of clusters, where each cluster is a list of Entry structs.
  # Clusters with 2+ semantically related entries from distinct categories.
  defp build_clusters(pairs) do
    # Build adjacency: {entry_a, entry_b, similarity}
    # Union-find via a map of id -> canonical_id
    parent = build_union_find(pairs)

    # Group entries by their canonical root
    entry_by_id =
      pairs
      |> Enum.flat_map(fn {e1, e2, _sim} -> [{e1.id, e1}, {e2.id, e2}] end)
      |> Map.new()

    groups =
      entry_by_id
      |> Map.keys()
      |> Enum.group_by(fn id -> find_root(parent, id) end)

    # Return clusters of 2+ entries, capped at @max_cluster_size
    groups
    |> Map.values()
    |> Enum.filter(fn ids -> length(ids) >= 2 end)
    |> Enum.map(fn ids ->
      ids
      |> Enum.take(@max_cluster_size)
      |> Enum.map(&Map.fetch!(entry_by_id, &1))
    end)
  end

  defp build_union_find(pairs) do
    # Initialize: each node is its own root
    initial =
      pairs
      |> Enum.flat_map(fn {e1, e2, _} -> [e1.id, e2.id] end)
      |> Enum.uniq()
      |> Map.new(&{&1, &1})

    # Union each pair
    Enum.reduce(pairs, initial, fn {e1, e2, _sim}, parent ->
      root1 = find_root(parent, e1.id)
      root2 = find_root(parent, e2.id)

      if root1 == root2 do
        parent
      else
        # Merge: root1 points to root2
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
  # pgvector-native query — O(n²) similarity comparison in PostgreSQL,
  # leveraging the ivfflat index for performance.
  # ---------------------------------------------------------------------------

  defp fetch_semantic_pairs do
    cutoff = DateTime.add(DateTime.utc_now(), -@days_window * 24 * 3600, :second)

    Repo.all(
      from e1 in Entry,
        join: e2 in Entry,
        on: e1.id < e2.id,
        where:
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
          e1,
          e2,
          fragment("1 - (? <=> ?)", e1.embedding, e2.embedding)
        }
    )
  end
end
