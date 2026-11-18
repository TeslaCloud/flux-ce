#!/bin/bash
# Entry point of the development image (Dockerfile.dev). Checks that the schema
# and its packages are in place, writes the parts of the configuration that
# depend on the containers into the config folder of the schema and starts the
# server with the schema as its gamemode.
# The arguments are passed on to the server.
set -euo pipefail

schema=${FLUX_SCHEMA:-reborn}
environment=${FLUX_ENV:-development}
gamemode=garrysmod/gamemodes/$schema
config=$gamemode/config
checkout=/home/steam/schema

if [ ! -f "$gamemode/$schema.txt" ]; then
  echo "There is no \"$schema\" schema at $gamemode." >&2
  echo "Point FLUX_SCHEMA_PATH at a checkout of it." >&2
  exit 1
fi

if [ ! -f "$gamemode/packages/flux/boot.lua" ]; then
  echo "Flux is not installed at $gamemode/packages/flux." >&2
  echo "Run \"fpkg link ../flux-ce\" or \"fpkg install\" in the schema checkout." >&2
  exit 1
fi

# The "packages" folder of the schema is covered by a tmpfs that holds the
# mounted packages. The folders that "fpkg install" put into the checkout are
# linked into it from the read-only view of the checkout; links of the checkout
# point outside of the container and need a mount of their own.
if [ -d "$checkout/packages" ]; then
  for entry in "$checkout/packages"/*; do
    id=$(basename "$entry")

    if [ -e "$gamemode/packages/$id" ]; then
      continue
    fi

    if [ -L "$entry" ]; then
      echo "Warning: packages/$id of the schema checkout is a link that is not mounted into the container." >&2
      echo "Start the stack with flux-server, or bind mount the folder it links to at" >&2
      echo "$PWD/$gamemode/packages/$id in docker-compose.override.yml." >&2
    elif [ -d "$entry" ]; then
      ln -s "$entry" "$gamemode/packages/$id"
    fi
  done
fi

if [ ! -f "$gamemode/packages/gmsv_file/packagespec.lua" ]; then
  echo "The gmsv_file package, which Flux cannot start without, is not at $gamemode/packages/gmsv_file." >&2
  echo "Run \"fpkg link ../gmsv_file\" or \"fpkg install\" in the schema checkout and mount it." >&2
  exit 1
fi

# The "config" folder of the schema is covered by a tmpfs, so that the files
# written below stay out of the checkout. Start with a copy of its real files.
mkdir -p "$config"

if [ -d "$checkout/config" ]; then
  cp -r "$checkout/config/." "$config/"
fi

echo "return '$environment'" > "$config/environment.local.lua"

# The database containers only exist when their compose profile is enabled, so
# the name of the one that resolves tells which database to use.
if getent hosts postgres > /dev/null; then
  adapter=pg host=postgres port=5432
elif getent hosts mariadb > /dev/null; then
  adapter=mysqloo host=mariadb port=3306
else
  adapter=sqlite host=127.0.0.1 port=0
fi

cat > "$config/database.local.yml" <<EOF
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
