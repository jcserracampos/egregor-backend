defmodule Egregor.Repo do
  use Ecto.Repo,
    otp_app: :egregor,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    {:ok, Keyword.put(config, :types, Egregor.PostgresTypes)}
  end
end
