defmodule Egregor.Repo.Migrations.AddTransmutationToEntries do
  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :transmuted_at, :utc_datetime
      add :transmutation_note, :text
    end

    create index(:entries, [:transmuted_at])
  end
end
