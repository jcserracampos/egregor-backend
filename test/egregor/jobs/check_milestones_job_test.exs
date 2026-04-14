defmodule Egregor.Jobs.CheckMilestonesJobTest do
  use Egregor.DataCase, async: false

  alias Egregor.Jobs.CheckMilestonesJob
  alias Egregor.Milestones.Milestone
  alias Egregor.Entries.Entry

  defp insert_entries(count) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(1..count, fn i ->
        %{
          id: Ecto.UUID.generate(),
          raw_text: "entry #{i}",
          categories: [],
          urgency: "low",
          is_intention: false,
          is_shadow: false,
          is_narrative: false,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Entry, rows)
  end

  defp milestone_exists?(type) do
    import Ecto.Query
    Repo.exists?(from m in Milestone, where: m.type == ^type)
  end

  defp milestone_count(type) do
    import Ecto.Query
    Repo.aggregate(from(m in Milestone, where: m.type == ^type), :count, :id)
  end

  describe "perform/1" do
    test "does not insert milestone when threshold is not reached" do
      insert_entries(50)

      assert :ok = CheckMilestonesJob.perform(%Oban.Job{args: %{}})

      refute milestone_exists?("constellation")
    end

    test "inserts constellation milestone when 100 entries are reached" do
      insert_entries(100)

      assert :ok = CheckMilestonesJob.perform(%Oban.Job{args: %{}})

      assert milestone_exists?("constellation")

      milestone = Repo.get_by!(Milestone, type: "constellation")
      assert milestone.threshold == 100
      assert milestone.reached_at != nil
    end

    test "does not duplicate milestone when called twice with 100 entries" do
      insert_entries(100)

      assert :ok = CheckMilestonesJob.perform(%Oban.Job{args: %{}})
      assert :ok = CheckMilestonesJob.perform(%Oban.Job{args: %{}})

      assert milestone_count("constellation") == 1
    end
  end
end
