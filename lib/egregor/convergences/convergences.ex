defmodule Egregor.Convergences do
  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Convergences.Convergence

  def latest_unseen do
    Convergence
    |> where([c], c.seen == false)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def mark_seen(%Convergence{} = convergence) do
    convergence
    |> Ecto.Changeset.change(seen: true)
    |> Repo.update()
  end
end
