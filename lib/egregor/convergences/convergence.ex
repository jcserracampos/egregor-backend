defmodule Egregor.Convergences.Convergence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "convergences" do
    field :entry_ids, {:array, :binary_id}, default: []
    field :message, :string
    field :pattern_type, :string
    field :seen, :boolean, default: false

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(convergence, attrs) do
    convergence
    |> cast(attrs, [:entry_ids, :message, :pattern_type, :seen])
    |> validate_required([:entry_ids, :message, :pattern_type])
  end
end
