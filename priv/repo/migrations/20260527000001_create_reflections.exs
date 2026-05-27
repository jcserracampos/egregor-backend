defmodule Egregor.Repo.Migrations.CreateReflections do
  use Ecto.Migration

  def change do
    create table(:reflections, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :content, :text, null: false
      add :kind, :text, null: false, default: "pulse"
      add :tone, :text
      add :source_entry_ids, {:array, :binary_id}, null: false, default: []
      add :consolidated, :boolean, null: false, default: false
      add :consolidated_at, :utc_datetime

      add :consolidated_into_id,
          references(:reflections, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:reflections, [:kind])
    create index(:reflections, [:consolidated])
    create index(:reflections, [:inserted_at])
    # Query path of the nightly consolidator: unconsolidated pulses since a cutoff.
    create index(:reflections, [:consolidated, :kind, :inserted_at])
  end
end
