defmodule Egregor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ets.new(:oracle_phrase_cache, [:named_table, :public, read_concurrency: true])

    children = [
      EgregorWeb.Telemetry,
      Egregor.Repo,
      {DNSCluster, query: Application.get_env(:egregor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Egregor.PubSub},
      {Oban, Application.fetch_env!(:egregor, Oban)},
      EgregorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Egregor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EgregorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
