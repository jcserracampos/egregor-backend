defmodule EgregorWeb.EntryController do
  use EgregorWeb, :controller

  alias Egregor.Entries
  alias Egregor.Agents.OpenRouter
  alias Egregor.Jobs.{TranscribeAudioJob, TransmutationJob}

  # Semantic search when ?query= present
  def index(conn, %{"query" => query} = _params) when query != "" do
    case OpenRouter.embed(query) do
      {:ok, embedding} ->
        entries = Entries.semantic_search(embedding, 20, 0.25)
        json(conn, %{data: Enum.map(entries, &serialize/1)})

      {:error, _} ->
        json(conn, %{data: []})
    end
  end

  def index(conn, params) do
    opts = [
      category: params["category"],
      intention: params["intention"] == "true",
      limit: parse_limit(params["limit"])
    ]

    entries = Entries.list_entries(opts)
    json(conn, %{data: Enum.map(entries, &serialize/1)})
  end

  def create(conn, params) do
    attrs = %{
      raw_text: params["raw_text"] || "",
      audio_path: params["audio_path"]
    }

    # If audio_path present but no text, set a placeholder
    attrs =
      if attrs.audio_path && attrs.raw_text == "" do
        Map.put(attrs, :raw_text, "[transcribing...]")
      else
        attrs
      end

    case Entries.create_entry(attrs) do
      {:ok, entry} ->
        # If entry has audio but no text, queue transcription (high priority)
        if entry.audio_path do
          %{"entry_id" => entry.id}
          |> TranscribeAudioJob.new(priority: 0)
          |> Oban.insert()
        end

        conn
        |> put_status(:created)
        |> json(%{data: serialize(entry)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    entry = Entries.get_entry!(id)
    json(conn, %{data: serialize(entry)})
  end

  @audio_content_types ~w(audio/mpeg audio/mp4 audio/wav audio/x-m4a audio/aac audio/ogg)
  @max_audio_size 50 * 1024 * 1024

  def create_audio(conn, %{"audio" => %Plug.Upload{} = upload}) do
    with :ok <- validate_audio_type(upload.content_type),
         :ok <- validate_file_size(upload.path) do
      ext = upload.filename |> Path.extname() |> String.downcase()
      filename = "#{Ecto.UUID.generate()}#{ext}"
      dest_dir = Application.app_dir(:egregor, "priv/uploads")
      dest = Path.join(dest_dir, filename)

      File.mkdir_p!(dest_dir)
      File.cp!(upload.path, dest)

      attrs = %{audio_path: "priv/uploads/#{filename}", raw_text: "[transcribing...]"}

      case Entries.create_entry(attrs) do
        {:ok, entry} ->
          %{"entry_id" => entry.id}
          |> TranscribeAudioJob.new(priority: 0)
          |> Oban.insert()

          conn
          |> put_status(:created)
          |> json(%{data: serialize(entry)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_errors(changeset)})
      end
    else
      {:error, :invalid_type} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid audio format. Accepted: m4a, mp3, wav"})

      {:error, :too_large} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Audio file too large. Maximum 50 MB"})
    end
  end

  def create_audio(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "audio file is required"})
  end

  def transmute(conn, %{"id" => id} = params) do
    entry = Entries.get_entry!(id)
    note = params["note"]

    %{"entry_id" => id, "note" => note}
    |> TransmutationJob.new()
    |> Oban.insert()

    json(conn, %{data: serialize(entry)})
  end

  def delete(conn, %{"id" => id}) do
    entry = Entries.get_entry!(id)
    {:ok, _} = Egregor.Repo.delete(entry)
    send_resp(conn, :no_content, "")
  end

  def update(conn, %{"id" => id} = params) do
    entry = Entries.get_entry!(id)

    allowed = ~w(raw_text categories urgency is_intention is_shadow)
    attrs = Map.take(params, allowed)

    case Entries.update_entry(entry, attrs) do
      {:ok, updated} ->
        json(conn, %{data: serialize(updated)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp serialize(entry) do
    %{
      id: entry.id,
      raw_text: entry.raw_text,
      audio_path: entry.audio_path,
      transcription: entry.transcription,
      categories: entry.categories,
      urgency: entry.urgency,
      is_intention: entry.is_intention,
      is_shadow: entry.is_shadow,
      is_narrative: entry.is_narrative,
      sigil_data: entry.sigil_data,
      summary: entry.summary,
      transmuted_at: entry.transmuted_at,
      transmutation_note: entry.transmutation_note,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp validate_audio_type(content_type) when content_type in @audio_content_types, do: :ok
  defp validate_audio_type(_), do: {:error, :invalid_type}

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_audio_size -> :ok
      _ -> {:error, :too_large}
    end
  end

  defp parse_limit(nil), do: nil
  defp parse_limit(str), do: String.to_integer(str)

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
