#!/bin/sh
set -e

# Extract host and port from DATABASE_URL for fast TCP-level wait
# DATABASE_URL format: ecto://USER:PASS@HOST:PORT/DB  or  postgres://...
db_host_port=$(printf '%s' "$DATABASE_URL" | sed -E 's|^[a-z]+://[^@]+@([^/]+)/.*|\1|')
db_host=$(printf '%s' "$db_host_port" | cut -d: -f1)
db_port=$(printf '%s' "$db_host_port" | cut -d: -f2)
[ -z "$db_port" ] && db_port=5432

echo "Waiting for database at ${db_host}:${db_port}..."
tries=0
until pg_isready -h "$db_host" -p "$db_port" -q; do
  tries=$((tries + 1))
  if [ $tries -ge 60 ]; then
    echo "Database never became ready after 60 attempts. Aborting."
    exit 1
  fi
  sleep 2
done

echo "Running migrations..."
/app/bin/egregor eval "Egregor.Release.migrate()"

echo "Seeding default categories..."
/app/bin/egregor eval "Egregor.Release.seed()"

echo "Starting Egrégor..."
exec /app/bin/egregor "$@"
