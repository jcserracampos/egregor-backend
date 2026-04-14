defmodule Egregor.Repo.Migrations.CreateConvergences do
  use Ecto.Migration

  def change do
    create table(:convergences, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :entry_ids, {:array, :binary_id}, null: false, default: []
      add :message, :text, null: false
      add :pattern_type, :text, null: false
      add :seen, :boolean, null: false, default: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:convergences, [:seen])
    create index(:convergences, [:inserted_at])
  end
end
