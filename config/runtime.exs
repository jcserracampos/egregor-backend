import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/egregor start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :egregor, EgregorWeb.Endpoint, server: true
end

bind_ip =
  case System.get_env("PHX_BIND_IP", "127.0.0.1") do
    "0.0.0.0" -> {0, 0, 0, 0}
    "127.0.0.1" -> {127, 0, 0, 1}
    other ->
      other
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()
  end

config :egregor, EgregorWeb.Endpoint,
  http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT", "4000"))]

# User identity — injected into Oracle system prompt
config :egregor, :user_name, System.get_env("USER_NAME", "você")

# Local timezone offset in hours (default -3 for America/Sao_Paulo / BRT)
config :egregor, :tz_offset_hours,
  String.to_integer(System.get_env("TZ_OFFSET_HOURS", "-3"))

# OpenRouter configuration (required in all envs when running)
if openrouter_key = System.get_env("OPENROUTER_API_KEY") do
  config :egregor, :openrouter,
    api_key: openrouter_key,
    base_url: "https://openrouter.ai/api/v1"
end

# Model overrides via environment variables
config :egregor, :models,
  embedding: System.get_env("EMBEDDING_MODEL", "openai/text-embedding-3-small"),
  taxonomist: System.get_env("TAXONOMIST_MODEL", "google/gemini-2.0-flash-lite-001"),
  oracle: System.get_env("ORACLE_MODEL", "anthropic/claude-sonnet-4.5"),
  phrase: System.get_env("PHRASE_MODEL", "google/gemini-2.0-flash-lite-001"),
  convergent: System.get_env("CONVERGENT_MODEL", "google/gemini-2.0-flash-lite-001"),
  narrator: System.get_env("NARRATOR_MODEL", "anthropic/claude-sonnet-4-5"),
  scribe: System.get_env("SCRIBE_MODEL", "openai/whisper-large-v3")

# DATABASE_URL overrides dev.exs when running in Docker or any env that sets it
if database_url = System.get_env("DATABASE_URL") do
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :egregor, Egregor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6
end

if config_env() == :prod do
  unless System.get_env("DATABASE_URL") do
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """
  end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :egregor, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :egregor, EgregorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :egregor, EgregorWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :egregor, EgregorWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
