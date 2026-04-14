defmodule Egregor.Entries.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "entries" do
    field :raw_text, :string
    field :audio_path, :string
    field :transcription, :string
    field :categories, {:array, :string}, default: []
    field :urgency, :string, default: "low"
    field :is_intention, :boolean, default: false
    field :is_shadow, :boolean, default: false
    field :is_narrative, :boolean, default: false
    field :sigil_data, :map
    field :embedding, Pgvector.Ecto.Vector
    field :summary, :string
    field :transmuted_at, :utc_datetime
    field :transmutation_note, :string

    timestamps(type: :utc_datetime)
  end

  @allowed_urgencies ~w(low med high)

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :raw_text,
      :audio_path,
      :transcription,
      :categories,
      :urgency,
      :is_intention,
      :is_shadow,
      :is_narrative,
      :sigil_data,
      :embedding,
      :summary
    ])
    |> validate_required([:raw_text])
    |> validate_inclusion(:urgency, @allowed_urgencies)
  end

  def embedding_changeset(entry, embedding) do
    change(entry, embedding: embedding)
  end

  def categorize_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:categories, :urgency, :is_shadow, :summary])
    |> validate_inclusion(:urgency, @allowed_urgencies)
  end

  def intention_changeset(entry, attrs) do
    cast(entry, attrs, [:is_intention, :sigil_data])
  end

  def transmute_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:transmuted_at, :transmutation_note])
    |> validate_required([:transmuted_at])
  end
end
