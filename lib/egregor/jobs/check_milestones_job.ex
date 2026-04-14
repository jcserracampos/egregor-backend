defmodule Egregor.Jobs.CheckMilestonesJob do
  use Oban.Worker, queue: :default, max_attempts: 2

  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Entries
  alias Egregor.Milestones.Milestone

  @thresholds [
    {100, "constellation", "Constelação"},
    {250, "second_layer", "Segunda Camada"},
    {500, "nebula", "Nebulosa"},
    {1000, "grimoire", "O Grimório Vivo"}
  ]

  @impl Oban.Worker
  def perform(_job) do
    count = Entries.count_entries()
    existing_types = fetch_existing_milestone_types()

    @thresholds
    |> Enum.each(fn {threshold, type, _name} ->
      if count >= threshold and type not in existing_types do
        %Milestone{}
        |> Milestone.changeset(%{
          type: type,
          threshold: threshold,
          reached_at: DateTime.utc_now() |> DateTime.truncate(:second),
          metadata: %{entry_count_at_milestone: count}
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: :type)
      end
    end)

    :ok
  end

  defp fetch_existing_milestone_types do
    from(m in Milestone, select: m.type)
    |> Repo.all()
  end
end
