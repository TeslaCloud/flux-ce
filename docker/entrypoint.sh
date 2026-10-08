#!/bin/bash
# Entry point of the development image (Dockerfile.dev). Writes the parts of the
# Flux configuration that depend on the containers and starts the server.
# The arguments are passed on to the server.
set -euo pipefail

flux=garrysmod/gamemodes/flux
schema=${FLUX_SCHEMA:-reborn}
environment=${FLUX_ENV:-development}

if [ ! -f "$flux/gamemode/init.lua" ]; then
  echo "Flux is not mounted at $flux." >&2
  exit 1
fi

if [ ! -f "garrysmod/gamemodes/$schema/$schema.txt" ]; then
  echo "There is no \"$schema\" schema at garrysmod/gamemodes/$schema." >&2
  echo "Point FLUX_SCHEMA_PATH at a checkout of it." >&2
  exit 1
fi

# The "config" folder of the checkout is covered by a tmpfs, so that the files
# written below stay out of the checkout. Start with a copy of the real files.
cp -r /home/steam/flux_config/. "$flux/config/"

echo "return '$environment'" > "$flux/config/environment.local.lua"

# The database containers only exist when their compose profile is enabled, so
# the name of the one that resolves tells which database to use.
if getent hosts postgres > /dev/null; then
  adapter=pg host=postgres port=5432
elif getent hosts mariadb > /dev/null; then
  adapter=mysqloo host=mariadb port=3306
else
  adapter=sqlite host=127.0.0.1 port=0
fi

cat > "$flux/config/database.local.yml" <<EOF
$environment:
  adapter: "$adapter"
  encoding: "utf8"
  host: "$host"
  user: "flux"
  password: "flux"
  database: "flux"
  port: $port
EOF

echo "Starting the \"$schema\" schema in the $environment environment, database adapter: $adapter"

args=(-norestart +hide_server 1 +gamemode "$schema")

if [ -n "${FLUX_WORKSHOP_COLLECTION:-}" ]; then
  args+=(+host_workshop_collection "$FLUX_WORKSHOP_COLLECTION")
fi

exec ./srcds_run_x64 "${args[@]}" "$@"
