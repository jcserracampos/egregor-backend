#!/bin/sh
set -e

echo "Waiting for database to be ready..."
until mix ecto.create --quiet 2>/dev/null; do
  echo "  db not ready yet, retrying in 2s..."
  sleep 2
done

echo "Running migrations..."
mix ecto.migrate

echo "Seeding default categories..."
mix run priv/repo/seeds.exs

echo "Starting Egrégor (MIX_ENV=${MIX_ENV})..."
exec mix phx.server
