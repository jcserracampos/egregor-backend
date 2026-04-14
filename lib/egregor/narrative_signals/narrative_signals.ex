defmodule Egregor.NarrativeSignals do
  import Ecto.Query

  alias Egregor.Repo
  alias Egregor.NarrativeSignals.NarrativeSignal

  def create_signal(attrs) do
    %NarrativeSignal{}
    |> NarrativeSignal.changeset(attrs)
    |> Repo.insert()
  end

  def list_for_entry(entry_id) do
    Repo.all(from s in NarrativeSignal, where: s.entry_id == ^entry_id)
  end

  def list_unconsumed do
    Repo.all(from s in NarrativeSignal, where: is_nil(s.consumed_at))
  end

  def list_by_type(signal_type) do
    Repo.all(from s in NarrativeSignal, where: s.signal_type == ^signal_type)
  end

  def list_unconsumed_by_type(signal_type) do
    Repo.all(
      from s in NarrativeSignal,
        where: s.signal_type == ^signal_type and is_nil(s.consumed_at)
    )
  end

  def mark_consumed(%NarrativeSignal{} = signal) do
    signal
    |> NarrativeSignal.consume_changeset()
    |> Repo.update()
  end

  def mark_consumed_batch(signals) do
    ids = Enum.map(signals, & &1.id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(
      from(s in NarrativeSignal, where: s.id in ^ids),
      set: [consumed_at: now]
    )
  end
end
