# Multi-stage build — production release
# ---
# Stage 1: build
FROM elixir:1.18-otp-27 AS build

WORKDIR /app

ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

RUN apt-get update -q && apt-get install -y --no-install-recommends \
    build-essential git \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

# Deps separately — cached layer unless mix.exs/mix.lock change
COPY mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV}
RUN mix deps.compile

# Config must come before compile
COPY config config

RUN mix compile

COPY priv priv
COPY lib lib
COPY rel rel

RUN mix release

# ---
# Stage 2: runtime (minimal image)
FROM debian:bookworm-slim AS app

RUN apt-get update -q && apt-get install -y --no-install-recommends \
    libssl3 libncurses6 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/_build/prod/rel/egregor ./
COPY --from=build /app/rel/overlays/bin/docker-entrypoint.sh /app/bin/

RUN chmod +x /app/bin/docker-entrypoint.sh

EXPOSE 4000

ENV PHX_SERVER=true

ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
CMD ["start"]
