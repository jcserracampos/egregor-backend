defmodule Egregor.Repo.Migrations.CreateFilaments do
  use Ecto.Migration

  def change do
    create table(:filaments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text
      add :centroid_embedding, :vector, size: 1536
      add :entry_count, :integer, null: false, default: 0
      add :last_linked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    execute(
      "CREATE INDEX filaments_centroid_idx ON filaments USING ivfflat (centroid_embedding vector_cosine_ops) WITH (lists = 100)",
      "DROP INDEX IF EXISTS filaments_centroid_idx"
    )
  end
end
