defmodule Egregor.Chat.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "chat_messages" do
    field :role, :string
    field :content, :string
    field :audio_path, :string
    field :entry_refs, {:array, :binary_id}, default: []

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :audio_path, :entry_refs])
    |> validate_required([:role, :content])
    |> validate_inclusion(:role, ["user", "assistant"])
  end
end
