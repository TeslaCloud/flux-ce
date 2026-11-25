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

# A glob that matches nothing, such as the one of a checkout without packages,
# expands to nothing instead of to itself.
shopt -s nullglob

# The "packages" folder of the schema is covered by a tmpfs that holds the
# mounted packages. The folders that "fpkg install" put into the checkout are
# linked into it from the read-only view of the checkout. Links of the checkout,
# such as the ones "fpkg link" makes, point outside of the container and lead
# nowhere in it, so the ones that do not resolve are only collected here.
dangling=()

for entry in "$checkout/packages"/*; do
  id=$(basename "$entry")

  if [ -e "$gamemode/packages/$id" ]; then
    continue
  fi

  if [ -d "$entry" ]; then
    ln -s "$entry" "$gamemode/packages/$id"
  elif [ -L "$entry" ]; then
    dangling+=("$id")
  fi
done

# The image has the packages of the binary modules (Dockerfile.dev). Each one
# that is neither mounted nor a folder of the checkout is linked from the image,
# whether the checkout has a link for it or nothing at all.
for package in /home/steam/packages/*; do
  id=$(basename "$package")

  if [ -e "$gamemode/packages/$id" ]; then
    continue
  fi

  if [ -L "$checkout/packages/$id" ]; then
    reason="packages/$id of the schema checkout is a link to outside of the container"
  else
    reason="$id is not installed in the schema checkout"
  fi

  echo "$reason: using the $id package of the image."
  ln -s "$package" "$gamemode/packages/$id"
done

# The links that are left need the folder they point to on the host mounted.
for id in "${dangling[@]}"; do
  if [ ! -e "$gamemode/packages/$id" ]; then
    echo "Warning: packages/$id of the schema checkout is a link to $(readlink "$checkout/packages/$id"), outside of the container." >&2
    echo "Bind mount the folder it links to at" >&2
    echo "$PWD/$gamemode/packages/$id in docker-compose.override.yml." >&2
  fi
done

# Flux cannot start without gmsv_file. The image has a copy of it, so it is only
# missing when a mount or a folder of the checkout takes the place of that copy
# without being the package, or when the image was built without it.
if [ ! -f "$gamemode/packages/gmsv_file/packagespec.lua" ]; then
  echo "The gmsv_file package, which Flux cannot start without, is not at $gamemode/packages/gmsv_file." >&2

  if [ -e "$gamemode/packages/gmsv_file" ]; then
    echo "The folder there, a mount or a folder of the schema checkout, has no packagespec.lua and is used instead of the copy of the image." >&2
  else
    echo "The image has no copy of it either, rebuild it with \"docker compose build\"." >&2
  fi

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
