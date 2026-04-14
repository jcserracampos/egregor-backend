# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :egregor,
  ecto_repos: [Egregor.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :egregor, EgregorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: EgregorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Egregor.PubSub,
  live_view: [signing_salt: "kqJgI7Nq"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban queues configuration
config :egregor, Oban,
  repo: Egregor.Repo,
  queues: [
    default: 10,
    embeddings: 5,
    transcription: 3,
    categorization: 5,
    batch: 2
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # 03h BRT (UTC-3) = 06h UTC
       {"0 6 * * *", Egregor.Jobs.DetectConvergenceJob},
       # 04h BRT (UTC-3) = 07h UTC
       {"0 7 * * *", Egregor.Jobs.UpdateOracleContextJob}
     ]}
  ]

# Default model config (overridden via environment in runtime.exs)
config :egregor, :models,
  embedding: "openai/text-embedding-3-small",
  taxonomist: "google/gemini-2.0-flash-lite-001",
  oracle: "anthropic/claude-sonnet-4.5",
  phrase: "google/gemini-2.0-flash-lite-001",
  convergent: "google/gemini-2.0-flash-lite-001",
  narrator: "anthropic/claude-sonnet-4-5",
  scribe: "openai/whisper-large-v3"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
