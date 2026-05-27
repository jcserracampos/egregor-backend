defmodule EgregorWeb.ReflectionController do
  @moduledoc """
  Read-only window into the Egrégor's private memory — the reflections it forms
  on its own (pulses + nightly consolidations). Inspection/debug only, not a
  product feature: the agent's inner life is meant to color the Oracle's voice,
  not to be browsed as content.
  """
  use EgregorWeb, :controller

  alias Egregor.Reflections

  def index(conn, _params) do
    reflections = Reflections.list_for_debug(50)
    json(conn, %{data: Enum.map(reflections, &serialize/1)})
  end

  defp serialize(r) do
    %{
      id: r.id,
      kind: r.kind,
      tone: r.tone,
      content: r.content,
      consolidated: r.consolidated,
      consolidated_at: r.consolidated_at,
      consolidated_into_id: r.consolidated_into_id,
      source_entry_ids: r.source_entry_ids,
      created_at: r.inserted_at
    }
  end
end
