import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :egregor, Egregor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "egregor_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :egregor, EgregorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "liuHle0FcuXgSkUrFuLZm3DLOm/zXwn6bwPCN+J3HdrmF8KFtR+wJgZ2183TEf9w",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban — insert jobs to DB but do not execute them during tests
config :egregor, Oban, testing: :manual
