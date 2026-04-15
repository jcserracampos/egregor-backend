defmodule EgregorWeb.FilamentController do
  use EgregorWeb, :controller

  alias Egregor.Filaments
  alias Egregor.Entries
  alias Egregor.Jobs.NameFilamentJob

  def index(conn, params) do
    opts = [limit: parse_limit(params["limit"])]
    filaments = Filaments.list_filaments(opts)
    json(conn, %{data: Enum.map(filaments, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    filament = Filaments.get_filament_with_entries(id)
    json(conn, %{data: serialize_with_entries(filament)})
  end

  # POST /api/filaments — body: {entry_ids: [uuid_a, uuid_b]}
  def create(conn, %{"entry_ids" => [id_a, id_b]}) do
    entry_a = Entries.get_entry!(id_a)
    entry_b = Entries.get_entry!(id_b)

    case Filaments.link_entries(entry_a, entry_b) do
      {:ok, filament} ->
        enqueue_naming(filament.id)

        conn
        |> put_status(:created)
        |> json(%{data: serialize_with_entries(filament)})

      {:error, :filament_conflict, existing} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "filament_conflict", existing_filaments: existing})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "entry_ids with exactly 2 elements is required"})
  end

  # POST /api/filaments/:id/entries — body: {entry_id: uuid}
  def add_entry(conn, %{"id" => filament_id, "entry_id" => entry_id}) do
    filament = Filaments.get_filament!(filament_id)
    entry = Entries.get_entry!(entry_id)

    case Filaments.add_entry(filament, entry) do
      {:ok, updated} ->
        enqueue_naming(updated.id)
        json(conn, %{data: serialize_with_entries(updated)})

      {:error, :filament_conflict, existing} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "filament_conflict", existing_filaments: existing})
    end
  end

  def add_entry(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "entry_id is required"})
  end

  # ---------------------------------------------------------------------------
  # Serializers
  # ---------------------------------------------------------------------------

  defp serialize(filament) do
    %{
      id: filament.id,
      name: filament.name,
      entry_count: filament.entry_count,
      last_linked_at: filament.last_linked_at,
      inserted_at: filament.inserted_at,
      updated_at: filament.updated_at
    }
  end

  defp serialize_with_entries(filament) do
    entries = Map.get(filament, :entries, [])

    serialize(filament)
    |> Map.put(:entries, Enum.map(entries, &serialize_entry/1))
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      raw_text: entry.raw_text,
      transcription: entry.transcription,
      categories: entry.categories,
      urgency: entry.urgency,
      is_intention: entry.is_intention,
      is_shadow: entry.is_shadow,
      summary: entry.summary,
      transmuted_at: entry.transmuted_at,
      transmutation_note: entry.transmutation_note,
      filament_id: entry.filament_id,
      filament_position: entry.filament_position,
      resurgence_pending: entry.resurgence_pending,
      inserted_at: entry.inserted_at
    }
  end

  defp parse_limit(nil), do: nil
  defp parse_limit(str), do: String.to_integer(str)

  defp enqueue_naming(filament_id) do
    %{"filament_id" => filament_id}
    |> NameFilamentJob.new()
    |> Oban.insert()
  end
end
