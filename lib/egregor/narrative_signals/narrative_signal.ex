defmodule Egregor.NarrativeSignals.NarrativeSignal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "narrative_signals" do
    field :signal_type, :string
    field :signal_data, :map, default: %{}
    field :consumed_at, :utc_datetime

    belongs_to :entry, Egregor.Entries.Entry

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, [:entry_id, :signal_type, :signal_data])
    |> validate_required([:entry_id, :signal_type])
    |> validate_inclusion(:signal_type, ~w(transmutation shadow_surfaced pattern_detected))
  end

  def consume_changeset(signal) do
    change(signal, consumed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
