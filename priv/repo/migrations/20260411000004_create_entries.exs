defmodule Egregor.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :raw_text, :text, null: false
      add :audio_path, :text
      add :transcription, :text
      add :categories, {:array, :text}, null: false, default: []
      add :urgency, :text, null: false, default: "low"
      add :is_intention, :boolean, null: false, default: false
      add :is_shadow, :boolean, null: false, default: false
      add :is_narrative, :boolean, null: false, default: false
      add :sigil_data, :map
      add :embedding, :vector, size: 1536
      add :summary, :text

      timestamps(type: :utc_datetime)
    end

    create constraint(:entries, :urgency_values,
             check: "urgency IN ('low', 'med', 'high')"
           )

    create index(:entries, [:inserted_at])
    create index(:entries, [:categories], using: :gin)
    create index(:entries, [:is_intention])
    create index(:entries, [:is_shadow])
    create index(:entries, [:is_narrative])

    execute(
      "CREATE INDEX entries_embedding_idx ON entries USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)",
      "DROP INDEX IF EXISTS entries_embedding_idx"
    )
  end
end
