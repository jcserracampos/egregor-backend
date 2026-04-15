defmodule Egregor.Repo.Migrations.AddFilamentToEntries do
  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :filament_id, references(:filaments, type: :binary_id, on_delete: :nilify_all)
      add :filament_position, :integer
      add :resurgence_pending, :boolean, null: false, default: false
      add :resurgence_marked_at, :utc_datetime
    end

    create index(:entries, [:filament_id])

    execute(
      "CREATE INDEX entries_resurgence_pending_idx ON entries (resurgence_pending) WHERE resurgence_pending = true AND filament_id IS NULL",
      "DROP INDEX IF EXISTS entries_resurgence_pending_idx"
    )
  end
end
