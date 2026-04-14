defmodule Egregor.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :role, :text, null: false
      add :content, :text, null: false
      add :audio_path, :text
      add :entry_refs, {:array, :binary_id}, default: []

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create constraint(:chat_messages, :role_values,
             check: "role IN ('user', 'assistant')"
           )

    create index(:chat_messages, [:inserted_at])
  end
end
