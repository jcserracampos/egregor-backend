defmodule Egregor.EntriesTest do
  use Egregor.DataCase, async: false
  use Oban.Testing, repo: Egregor.Repo

  alias Egregor.Entries
  alias Egregor.Entries.Entry
  alias Egregor.Jobs.{GenerateEmbeddingJob, CategorizeEntryJob, CheckMilestonesJob}

  describe "create_entry/1" do
    test "persists entry with correct fields" do
      assert {:ok, entry} = Entries.create_entry(%{raw_text: "test thought"})

      assert entry.raw_text == "test thought"
      assert entry.urgency == "low"
      assert entry.is_intention == false
      assert entry.is_shadow == false
      assert entry.categories == []
      assert entry.id != nil
    end

    test "returns error changeset when raw_text is missing" do
      assert {:error, changeset} = Entries.create_entry(%{})
      assert %{raw_text: [_ | _]} = errors_on(changeset)
    end

    test "enqueues GenerateEmbeddingJob, CategorizeEntryJob and CheckMilestonesJob" do
      assert {:ok, entry} = Entries.create_entry(%{raw_text: "enqueue test"})

      assert_enqueued(worker: GenerateEmbeddingJob, args: %{"entry_id" => entry.id})
      assert_enqueued(worker: CategorizeEntryJob, args: %{"entry_id" => entry.id})
      assert_enqueued(worker: CheckMilestonesJob)
    end
  end

  describe "list_entries/0" do
    test "returns entries in descending order by insertion time" do
      {:ok, first} = Entries.create_entry(%{raw_text: "first"})

      # Force a small time difference between inserts
      {:ok, second} =
        %Entry{}
        |> Entry.changeset(%{raw_text: "second"})
        |> Ecto.Changeset.force_change(:inserted_at, ~U[2099-01-02 00:00:00Z])
        |> Repo.insert()

      entries = Entries.list_entries()
      ids = Enum.map(entries, & &1.id)

      assert Enum.find_index(ids, &(&1 == second.id)) <
               Enum.find_index(ids, &(&1 == first.id))
    end
  end

  describe "update_entry/2" do
    test "updates raw_text and re-enqueues embedding and categorization jobs" do
      {:ok, entry} = Entries.create_entry(%{raw_text: "original"})

      assert {:ok, updated} = Entries.update_entry(entry, %{"raw_text" => "updated"})
      assert updated.raw_text == "updated"

      assert_enqueued(worker: GenerateEmbeddingJob, args: %{"entry_id" => entry.id})
      assert_enqueued(worker: CategorizeEntryJob, args: %{"entry_id" => entry.id})
    end

    test "does not re-enqueue jobs when raw_text is not changed" do
      {:ok, entry} = Entries.create_entry(%{raw_text: "original"})

      # Drain the jobs enqueued by create_entry
      Oban.drain_queue(queue: :default)
      Oban.drain_queue(queue: :embeddings)
      Oban.drain_queue(queue: :categorization)

      assert {:ok, _} = Entries.update_entry(entry, %{"urgency" => "high"})

      refute_enqueued(worker: GenerateEmbeddingJob, args: %{"entry_id" => entry.id})
      refute_enqueued(worker: CategorizeEntryJob, args: %{"entry_id" => entry.id})
    end
  end

  describe "semantic_search/3" do
    test "returns empty list when no entries have embeddings" do
      {:ok, _} = Entries.create_entry(%{raw_text: "no embedding here"})

      zero_vector = List.duplicate(0.0, 1536)
      results = Entries.semantic_search(zero_vector, 10, 0.3)

      assert results == []
    end
  end
end
