defmodule EgregorWeb.MilestoneController do
  use EgregorWeb, :controller

  alias Egregor.Milestones

  def index(conn, _params) do
    milestones = Milestones.list_milestones()
    json(conn, %{data: Enum.map(milestones, &serialize/1)})
  end

  defp serialize(m) do
    %{
      id: m.id,
      type: m.type,
      threshold: m.threshold,
      reached_at: m.reached_at,
      metadata: m.metadata
    }
  end
end
