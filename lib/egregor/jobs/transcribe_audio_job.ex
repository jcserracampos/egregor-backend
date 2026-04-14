defmodule Egregor.Jobs.TranscribeAudioJob do
  use Oban.Worker, queue: :transcription, max_attempts: 3, priority: 0

  alias Egregor.Repo
  alias Egregor.Entries.Entry
  alias Egregor.Agents.Scribe
  alias Egregor.Jobs.{GenerateEmbeddingJob, CategorizeEntryJob}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"entry_id" => entry_id}}) do
    entry = Repo.get!(Entry, entry_id)

    unless entry.audio_path do
      {:error, "entry has no audio_path"}
    else
      case Scribe.transcribe(entry.audio_path) do
        {:ok, transcription} ->
          entry
          |> Entry.changeset(%{
            raw_text: transcription,
            transcription: transcription
          })
          |> Repo.update!()

          %{"entry_id" => entry_id}
          |> GenerateEmbeddingJob.new()
          |> Oban.insert()

          %{"entry_id" => entry_id}
          |> CategorizeEntryJob.new()
          |> Oban.insert()

          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
