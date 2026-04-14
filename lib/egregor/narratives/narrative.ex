defmodule Egregor.Narratives.Narrative do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "narratives" do
    field :content, :string
    field :period_start, :date
    field :period_end, :date
    field :entry_ids, {:array, :binary_id}, default: []

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(narrative, attrs) do
    narrative
    |> cast(attrs, [:content, :period_start, :period_end, :entry_ids])
    |> validate_required([:content, :period_start, :period_end])
  end
end
