defmodule Egregor.Narratives do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Narratives.Narrative
  alias Egregor.Agents.Narrator
  alias Egregor.Entries
  alias Egregor.NarrativeSignals

  def list_recent(limit \\ 5) do
    Narrative
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def latest do
    Narrative
    |> order_by([n], desc: n.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def generate_for_week do
    today = Date.utc_today()
    week_start = Date.add(today, -7)

    entries = Entries.list_entries()
    previous = list_recent(3)
    transmutation_signals = NarrativeSignals.list_unconsumed_by_type("transmutation")

    case Narrator.generate(entries, previous, transmutation_signals) do
      {:ok, content} ->
        entry_ids = Enum.map(entries, & &1.id)

        result =
          %Narrative{}
          |> Narrative.changeset(%{
            content: content,
            period_start: week_start,
            period_end: today,
            entry_ids: entry_ids
          })
          |> Repo.insert()

        # Mark signals as consumed so they aren't included in future narratives
        NarrativeSignals.mark_consumed_batch(transmutation_signals)

        result

      error ->
        error
    end
  end
end
