defmodule Egregor.Jobs.ReflectionPulseJob do
  @moduledoc """
  Heartbeat. Every ~4h, lets the Egrégor form a raw, private observation about
  what entered since its last memory. Never messages the user (SPEC §III).

  Two guards keep it from inventing memory about nothing:
  1. if no new entries since the last pulse → returns `:ok` without calling the LLM;
  2. if the agent itself sees nothing substantial → returns `:ok` without storing.
  """
  use Oban.Worker, queue: :batch, max_attempts: 2

  alias Egregor.Agents.ReflectionAgent
  alias Egregor.{Entries, Oracle, Reflections}

  # Never look further back than this even if the last pulse is old (app idle),
  # so a long gap doesn't make stale entries look like "news".
  @max_lookback_hours 8

  @impl Oban.Worker
  def perform(_job) do
    new_entries = Entries.list_since(pulse_window_start())

    if new_entries == [] do
      :ok
    else
      new_entries
      |> ReflectionAgent.pulse(Oracle.get_context(), Reflections.recent_consolidated(2))
      |> store(new_entries)
    end
  end

  defp store({:ok, :empty}, _entries), do: :ok

  defp store({:ok, %{content: content, tone: tone}}, entries) do
    {:ok, _} =
      Reflections.create_pulse(%{
        content: content,
        tone: tone,
        source_entry_ids: Enum.map(entries, & &1.id)
      })

    :ok
  end

  defp store({:error, reason}, _entries), do: {:error, reason}

  defp pulse_window_start do
    now = DateTime.utc_now()
    cap = DateTime.add(now, -@max_lookback_hours * 3600, :second)

    case Reflections.last_pulse_at() do
      nil -> DateTime.add(now, -4 * 3600, :second)
      last -> if DateTime.compare(last, cap) == :lt, do: cap, else: last
    end
  end
end
