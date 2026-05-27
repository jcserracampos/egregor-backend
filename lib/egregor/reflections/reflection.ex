defmodule Egregor.Reflections.Reflection do
  @moduledoc """
  A private, first-person memory the Egrégor forms about the user.

  `kind` distinguishes a raw heartbeat observation ("pulse") from a durable
  learning distilled nightly ("consolidation"). Only consolidations feed the
  Oracle's voice. A pulse marked `consolidated: true` has been absorbed by the
  consolidation referenced in `consolidated_into_id`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kinds ~w(pulse consolidation)

  schema "reflections" do
    field :content, :string
    field :kind, :string, default: "pulse"
    field :tone, :string
    field :source_entry_ids, {:array, :binary_id}, default: []
    field :consolidated, :boolean, default: false
    field :consolidated_at, :utc_datetime
    field :consolidated_into_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(reflection, attrs) do
    reflection
    |> cast(attrs, [
      :content,
      :kind,
      :tone,
      :source_entry_ids,
      :consolidated,
      :consolidated_at,
      :consolidated_into_id
    ])
    |> validate_required([:content, :kind])
    |> validate_inclusion(:kind, @kinds)
  end
end
