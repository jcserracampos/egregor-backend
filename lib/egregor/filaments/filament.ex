defmodule Egregor.Filaments.Filament do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "filaments" do
    field :name, :string
    field :centroid_embedding, Pgvector.Ecto.Vector
    field :entry_count, :integer, default: 0
    field :last_linked_at, :utc_datetime

    has_many :entries, Egregor.Entries.Entry

    timestamps(type: :utc_datetime)
  end

  def changeset(filament, attrs) do
    filament
    |> cast(attrs, [:name, :entry_count, :last_linked_at])
  end

  def centroid_changeset(filament, centroid_embedding) do
    change(filament, centroid_embedding: centroid_embedding)
  end

  def name_changeset(filament, name) do
    change(filament, name: name)
  end
end
