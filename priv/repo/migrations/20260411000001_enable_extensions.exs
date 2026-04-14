defmodule Egregor.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS vector")
    execute(~s|CREATE EXTENSION IF NOT EXISTS "uuid-ossp"|)
  end

  def down do
    execute("DROP EXTENSION IF EXISTS vector")
    execute(~s|DROP EXTENSION IF EXISTS "uuid-ossp"|)
  end
end
