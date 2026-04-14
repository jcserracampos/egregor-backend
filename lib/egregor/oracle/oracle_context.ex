defmodule Egregor.Oracle.OracleContext do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "oracle_context" do
    field :vocabulary, :map, default: %{}
    field :obsessions, {:array, :string}, default: []
    field :cycles, :map, default: %{}
    field :raw_summary, :string

    timestamps(type: :utc_datetime, inserted_at: false)
  end

  def changeset(context, attrs) do
    context
    |> cast(attrs, [:vocabulary, :obsessions, :cycles, :raw_summary])
  end
end
