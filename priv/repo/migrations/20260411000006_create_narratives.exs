defmodule Egregor.Repo.Migrations.CreateNarratives do
  use Ecto.Migration

  def change do
    create table(:narratives, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content, :text, null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :entry_ids, {:array, :binary_id}, null: false, default: []

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:narratives, [:inserted_at])
    create index(:narratives, [:period_start, :period_end])
  end
end
