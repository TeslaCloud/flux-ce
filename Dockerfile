# The dependencies and the schema are fetched in their own stages, so that
# changes to them do not invalidate the large server download below.
# Build with "--no-cache-filter deps,schema" to pull in their newest versions.
FROM alpine/git AS deps
RUN git clone --depth 1 https://github.com/TeslaCloud/flux-dependencies.git /deps

FROM alpine/git AS schema
ARG SCHEMA_REPO=https://github.com/TeslaCloud/hl2rp.git
WORKDIR /schema
RUN git clone --depth 1 "$SCHEMA_REPO"

FROM steamcmd/steamcmd:debian-trixie

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

# The schema folder is named after its repository, "reborn" by default.
COPY --from=schema --chown=steam:steam /schema garrysmod/gamemodes

# Install this checkout of Flux as a gamemode. It has to be in the "flux" folder.
COPY --chown=steam:steam . garrysmod/gamemodes/flux

# Flux writes generated files here, but cannot create the folder on first boot.
RUN mkdir -p garrysmod/lua/_flux

EXPOSE 27015/udp 27015/tcp

ENTRYPOINT ["./srcds_run_x64"]
CMD ["+gamemode", "reborn", "+map", "gm_construct", "+maxplayers", "64", "-tickrate", "30"]
