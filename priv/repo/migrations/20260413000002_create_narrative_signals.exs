defmodule Egregor.Repo.Migrations.CreateNarrativeSignals do
  use Ecto.Migration

  def change do
    create table(:narrative_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :entry_id, references(:entries, type: :binary_id, on_delete: :delete_all), null: false
      add :signal_type, :text, null: false
      add :signal_data, :map, default: %{}
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:narrative_signals, [:entry_id])
    create index(:narrative_signals, [:signal_type])
    create index(:narrative_signals, [:consumed_at])
  end
end
