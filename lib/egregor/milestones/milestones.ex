defmodule Egregor.Milestones do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Milestones.Milestone

  def list_milestones do
    Repo.all(from m in Milestone, order_by: [asc: m.threshold])
  end
end
