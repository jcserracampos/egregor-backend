import Config

# HTTPS is enforced by the Coolify reverse proxy (Traefik), which also sets
# Strict-Transport-Security. We don't enable Plug.SSL/force_ssl here because
# it would issue 301 redirects on any request carrying `Upgrade: websocket`
# (the proxy doesn't forward X-Forwarded-Proto on WS upgrades), breaking
# Phoenix Channels.

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
