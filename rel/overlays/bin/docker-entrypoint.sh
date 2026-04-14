#!/bin/sh
set -e

# Wait for Postgres to be ready
until /app/bin/egregor eval "Egregor.Repo.query!(\"SELECT 1\")" > /dev/null 2>&1; do
  echo "Waiting for database..."
  sleep 2
done

echo "Running migrations..."
/app/bin/egregor eval "Egregor.Release.migrate()"

echo "Seeding default categories..."
/app/bin/egregor eval "Egregor.Release.seed()"

echo "Starting Egrégor..."
exec /app/bin/egregor "$@"
