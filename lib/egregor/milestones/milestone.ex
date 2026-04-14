defmodule Egregor.Milestones.Milestone do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "milestones" do
    field :type, :string
    field :threshold, :integer
    field :reached_at, :utc_datetime
    field :metadata, :map
  end

  def changeset(milestone, attrs) do
    milestone
    |> cast(attrs, [:type, :threshold, :reached_at, :metadata])
    |> validate_required([:type, :threshold])
    |> unique_constraint(:type)
  end
end
