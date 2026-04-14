defmodule Egregor.Repo.Migrations.CreateOracleContext do
  use Ecto.Migration

  def change do
    create table(:oracle_context, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :vocabulary, :map, null: false, default: %{}
      add :obsessions, {:array, :text}, null: false, default: []
      add :cycles, :map, null: false, default: %{}
      add :raw_summary, :text

      timestamps(type: :utc_datetime, inserted_at: false)
    end
  end
end
