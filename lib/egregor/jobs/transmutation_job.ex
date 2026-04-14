defmodule Egregor.Jobs.TransmutationJob do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Egregor.Entries
  alias Egregor.NarrativeSignals
  alias Egregor.Jobs.DetectConvergenceJob

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"entry_id" => entry_id} = args}) do
    note = Map.get(args, "note")
    entry = Entries.get_entry!(entry_id)

    {:ok, _updated} = Entries.transmute_entry(entry, note)

    {:ok, _signal} =
      NarrativeSignals.create_signal(%{
        entry_id: entry_id,
        signal_type: "transmutation",
        signal_data: %{
          original_text: entry.raw_text,
          note: note,
          categories: entry.categories,
          summary: entry.summary
        }
      })

    %{}
    |> DetectConvergenceJob.new()
    |> Oban.insert()

    :ok
  end
end
