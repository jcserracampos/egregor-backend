defmodule Egregor.Reflections do
  @moduledoc """
  The agent's own memories — private, first-person reflections the Egrégor
  forms about the user over time.

  Distinct from `Egregor.Oracle` / `OracleContext`, which is a profile of the
  *user*. This is the entity's accumulating inner life (Rubedo): what *it* has
  been noticing. It is never shown to the user as narrative — only fed back, as
  context, into the Oracle's voice and exposed read-only for debugging.

  Two kinds:
  - `"pulse"`         — raw, frequent observations (heartbeat, ~every 4h)
  - `"consolidation"` — durable learnings distilled nightly from the day's pulses

  Only consolidations feed the Oracle's prompt.
  """
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Reflections.Reflection

  @doc "Stores a raw heartbeat observation. `attrs` uses atom keys."
  def create_pulse(attrs) when is_map(attrs) do
    %Reflection{}
    |> Reflection.changeset(Map.put(attrs, :kind, "pulse"))
    |> Repo.insert()
  end

  @doc "Stores a durable learning distilled from pulses. `attrs` uses atom keys."
  def create_consolidation(attrs) when is_map(attrs) do
    %Reflection{}
    |> Reflection.changeset(Map.put(attrs, :kind, "consolidation"))
    |> Repo.insert()
  end

  @doc "Most recent durable learnings — these feed the Oracle's prompt."
  def recent_consolidated(limit \\ 3) do
    Reflection
    |> where([r], r.kind == "consolidation")
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Timestamp of the last pulse, or nil if none yet."
  def last_pulse_at do
    Reflection
    |> where([r], r.kind == "pulse")
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> select([r], r.inserted_at)
    |> Repo.one()
  end

  @doc "Raw, not-yet-consolidated pulses created since `cutoff`, oldest first."
  def unconsolidated_pulses_since(cutoff) do
    Reflection
    |> where([r], r.kind == "pulse" and r.consolidated == false and r.inserted_at > ^cutoff)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Marks raw pulses as absorbed by a consolidation. Idempotent: re-running only
  affects rows still matching the id list, and a second consolidation pass finds
  no unconsolidated pulses.
  """
  def mark_consolidated(pulse_ids, into_id) when is_list(pulse_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Reflection
    |> where([r], r.id in ^pulse_ids)
    |> Repo.update_all(
      set: [consolidated: true, consolidated_at: now, consolidated_into_id: into_id]
    )
  end

  @doc "Deletes raw pulses already consolidated before `older_than` (growth control)."
  def prune_consolidated_pulses(older_than) do
    Reflection
    |> where(
      [r],
      r.kind == "pulse" and r.consolidated == true and r.consolidated_at < ^older_than
    )
    |> Repo.delete_all()
  end

  @doc "Recent reflections of any kind, for the read-only debug endpoint."
  def list_for_debug(limit \\ 50) do
    Reflection
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
