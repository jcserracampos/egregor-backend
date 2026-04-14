defmodule Egregor.Repo.Migrations.UpdateShadowCategoryColors do
  use Ecto.Migration

  def up do
    execute("UPDATE categories SET color = '#1a1a3a', glow_color = '#2a2a6a' WHERE name = 'Sombra'")
  end

  def down do
    execute("UPDATE categories SET color = '#2a2a4a', glow_color = '#3a3a5a' WHERE name = 'Sombra'")
  end
end
