defmodule Egregor.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "categories" do
    field :name, :string
    field :color, :string
    field :glow_color, :string
    field :symbol, :string
    field :entry_count, :integer, default: 0
    field :awakened, :boolean, default: false
    field :awakened_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :color, :glow_color, :symbol, :entry_count, :awakened, :awakened_at])
    |> validate_required([:name, :color, :glow_color])
    |> unique_constraint(:name)
  end

  def awaken_changeset(category, symbol) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    change(category,
      symbol: symbol,
      awakened: true,
      awakened_at: now
    )
  end
end
