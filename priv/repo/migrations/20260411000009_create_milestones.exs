defmodule Egregor.Repo.Migrations.CreateMilestones do
  use Ecto.Migration

  def change do
    create table(:milestones, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :type, :text, null: false
      add :threshold, :integer, null: false
      add :reached_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :metadata, :map
    end

    create unique_index(:milestones, [:type])
    create index(:milestones, [:threshold])
  end
end
