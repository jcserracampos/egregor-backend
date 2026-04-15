defmodule EgregorWeb.HealthController do
  use EgregorWeb, :controller

  import Ecto.Query
  alias Egregor.Repo
  alias Egregor.Entries.Entry
  alias Egregor.Jobs.CategorizeEntryJob

  def check(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
  end

  def recategorize(conn, _params) do
    entries =
      from(e in Entry,
        where: fragment("coalesce(array_length(?, 1), 0) = 0", e.categories),
        select: e.id
      )
      |> Repo.all()

    enqueued =
      Enum.map(entries, fn id ->
        {:ok, _} =
          %{"entry_id" => id}
          |> CategorizeEntryJob.new()
          |> Oban.insert()

        id
      end)

    json(conn, %{enqueued: length(enqueued), ids: enqueued})
  end

  def debug(conn, _params) do
    openrouter = Application.get_env(:egregor, :openrouter)

    queue_counts =
      try do
        from(j in "oban_jobs",
          group_by: [j.state, j.queue],
          select: {j.state, j.queue, count(j.id)}
        )
        |> Repo.all()
        |> Enum.map(fn {state, queue, n} -> %{state: state, queue: queue, count: n} end)
      rescue
        e -> %{error: Exception.message(e)}
      end

    recent_errors =
      try do
        from(j in "oban_jobs",
          where: j.state in ["retryable", "discarded", "cancelled"],
          order_by: [desc: j.id],
          limit: 5,
          select: %{
            id: j.id,
            worker: j.worker,
            state: j.state,
            attempt: j.attempt,
            errors: j.errors,
            inserted_at: j.inserted_at
          }
        )
        |> Repo.all()
      rescue
        e -> %{error: Exception.message(e)}
      end

    recent_jobs =
      try do
        from(j in "oban_jobs",
          order_by: [desc: j.id],
          limit: 10,
          select: %{id: j.id, worker: j.worker, state: j.state, queue: j.queue}
        )
        |> Repo.all()
      rescue
        e -> %{error: Exception.message(e)}
      end

    oban_running =
      try do
        Oban.check_queue(queue: :categorization)
      rescue
        e -> %{error: Exception.message(e)}
      end

    json(conn, %{
      openrouter_configured: not is_nil(openrouter),
      openrouter_key_present: not is_nil(openrouter && openrouter[:api_key]),
      models: (Application.get_env(:egregor, :models) || []) |> Map.new(),
      oban_categorization_queue: inspect(oban_running),
      queue_counts: queue_counts,
      recent_jobs: recent_jobs,
      recent_errors: recent_errors
    })
  end
end
