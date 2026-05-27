defmodule Egregor.Jobs.ConsolidateReflectionsJob do
  @moduledoc """
  Nightly consolidation (ritual window). Distils the day's raw pulses into a
  single durable learning, marks the pulses as absorbed, and prunes old absorbed
  pulses. The durable learnings are what feed back into the Oracle's voice.

  `max_attempts: 1` on purpose: a retry could create a duplicate consolidation.
  If it fails, the next night's run picks up the still-unconsolidated pulses.
  Idempotent within a day: a second run finds no unconsolidated pulses.
  """
  use Oban.Worker, queue: :batch, max_attempts: 1

  alias Egregor.Agents.ReflectionAgent
  alias Egregor.{Oracle, Reflections, Repo}

  @lookback_hours 24
  @prune_after_days 30

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@lookback_hours * 3600, :second)
    pulses = Reflections.unconsolidated_pulses_since(cutoff)

    if pulses == [] do
      :ok
    else
      pulses
      |> ReflectionAgent.consolidate(Oracle.get_context(), Reflections.recent_consolidated(2))
      |> store(pulses)
    end
  end

  defp store({:ok, :empty}, _pulses), do: :ok

  defp store({:ok, %{content: content, tone: tone}}, pulses) do
    source_ids =
      pulses
      |> Enum.flat_map(& &1.source_entry_ids)
      |> Enum.uniq()

    Repo.transaction(fn ->
      {:ok, consolidation} =
        Reflections.create_consolidation(%{
          content: content,
          tone: tone,
          source_entry_ids: source_ids
        })

      Reflections.mark_consolidated(Enum.map(pulses, & &1.id), consolidation.id)
    end)

    prune()
    :ok
  end

  defp store({:error, reason}, _pulses), do: {:error, reason}

  defp prune do
    older_than = DateTime.add(DateTime.utc_now(), -@prune_after_days * 86_400, :second)
    Reflections.prune_consolidated_pulses(older_than)
  end
end
