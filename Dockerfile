# The dependencies, the schema and the gmsv_file package are fetched in their own
# stages, so that changes to them do not invalidate the large server download
# below. Build with "--no-cache-filter deps,schema,gmsv_file" to pull in their
# newest versions.
FROM alpine/git:2.54.1 AS deps
RUN git clone --depth 1 https://github.com/TeslaCloud/flux-dependencies.git /deps

# Flux's build of the Lua library of the server, which replaces the stock
# bin/linux64/lua_shared.so. An empty LUA_SHARED_URL keeps the stock library.
# Build with "--no-cache-filter lua_shared" to download its newest version.
FROM alpine:3.24 AS lua_shared
ARG LUA_SHARED_URL=https://data.nighty.cloud/gmod/lua_shared.so
RUN mkdir /lua_shared && if [ -n "$LUA_SHARED_URL" ]; then \
      wget -q -O /lua_shared/lua_shared.so "$LUA_SHARED_URL"; \
    fi

# SCHEMA is the folder name of the schema, which is its gamemode; pass
# "+gamemode <SCHEMA>" to the server when it is not hl2rp.
FROM alpine/git:2.54.1 AS schema
ARG SCHEMA_REPO=https://github.com/TeslaCloud/hl2rp.git
ARG SCHEMA=hl2rp
RUN git clone --depth 1 "$SCHEMA_REPO" "/schema/$SCHEMA"

# The Lua side of the "file" binary module, a dependency of Flux. The module
# itself comes from the dependencies repo.
FROM alpine/git:2.54.1 AS gmsv_file
RUN git clone --depth 1 https://github.com/Meow/gmsv_file.git /gmsv_file

FROM steamcmd/steamcmd:debian-trixie
ARG SCHEMA=hl2rp

RUN useradd --create-home --shell /bin/bash steam

USER steam
ENV USER=steam HOME=/home/steam
WORKDIR /home/steam/flux_server

# Let steamcmd update itself first. Running the download right after the
# self-update tends to fail with "Missing configuration".
RUN steamcmd +quit

# Flux only ships 64-bit modules, so the server has to come from the x86-64 branch.
# The download is resumed on failure, which happens from time to time.
RUN attempt=0; until steamcmd +force_install_dir /home/steam/flux_server +login anonymous +app_update 4020 -beta x86-64 validate +quit; do \
      attempt=$((attempt + 1)); [ "$attempt" -lt 5 ] || exit 1; sleep 10; \
    done

# Put the binary modules from the dependencies repo on top of the server files.
COPY --from=deps --chown=steam:steam /deps/garrysmod garrysmod

# Replace the Lua library of the server, unless the build left it out.
COPY --from=lua_shared --chown=steam:steam --chmod=755 /lua_shared/ bin/linux64/

# The schema is the only gamemode. This checkout of Flux is its "flux" package,
# with the packages of Flux nested in it, and gmsv_file sits next to it. The
# fonts of the fontawesome package go to the content folder of the gamemode.
COPY --from=schema --chown=steam:steam /schema garrysmod/gamemodes
COPY --chown=steam:steam . garrysmod/gamemodes/$SCHEMA/packages/flux
COPY --from=gmsv_file --chown=steam:steam /gmsv_file garrysmod/gamemodes/$SCHEMA/packages/gmsv_file
COPY --chown=steam:steam packages/fontawesome/content/ garrysmod/gamemodes/$SCHEMA/content/

# Flux writes generated files here, but cannot create the folder on first boot.
RUN mkdir -p garrysmod/lua/_flux

EXPOSE 27015/udp 27015/tcp

ENTRYPOINT ["./srcds_run_x64"]
CMD ["+gamemode", "hl2rp", "+map", "gm_construct", "+maxplayers", "64", "-tickrate", "30"]
