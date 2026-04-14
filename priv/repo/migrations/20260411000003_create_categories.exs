defmodule Egregor.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :color, :text, null: false
      add :glow_color, :text, null: false
      add :symbol, :text
      add :entry_count, :integer, null: false, default: 0
      add :awakened, :boolean, null: false, default: false
      add :awakened_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:categories, [:name])
    create index(:categories, [:awakened])
    create index(:categories, [:entry_count])
  end
end
