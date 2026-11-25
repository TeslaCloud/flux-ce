![Imgur](https://i.imgur.com/o4bFhLn.png)

# Flux

## What is Flux?

Flux is a WIP gamemode framework designed with performance and convenience in mind. It comes with "batteries included" and features all you need to create engaging experiences with maximum comfort. Whether you are a developer wishing to create something with Flux, or a person looking to create their own server, Flux makes it easy to achieve your goals, and gives you the confidence of knowing everything will run smoothly.

## Development Version

The current version of Flux is currently in active development. This means that you can install it and it will run, but there will almost inevitably be bugs and issues, as well as a lot of missing features. If you are not a developer, it is probably better for you to wait until Flux is in beta.

## Important

**Flux is only guaranteed to work on dedicated servers (srcds). We do not support "listen" servers (launching from the Garry's Mod client).**

**Flux runs on 64-bit Linux (x86-64) servers only.** It is written in a newer Lua syntax than the stock Lua library of Garry's Mod reads, so the server needs Flux's own build of that library, `bin/linux64/lua_shared.so`, from https://data.nighty.cloud/gmod/lua_shared.so. That build exists for 64-bit Linux alone: there is none for Windows or for the 32-bit server. The Docker images below install it for you; on a server of your own, see [Installation](#installation).

**Please read these instructions carefully. We cannot provide support if you disregard one or more steps in these instructions. Thank you!**

## Docker (easy mode)

If you have Docker and simply want a running server, you can skip the installation guide below. The `Dockerfile` in this repository performs the steps from [Installation](#installation) for you: it installs the x86-64 Garry's Mod dedicated server, Flux's build of the Lua library, the binary modules, the HL2RP schema as the gamemode and this checkout as its `flux` package.

```sh
# Clone the Flux repository and build the image.
# This downloads the dedicated server (about 7 GB), so it will take a while.
git clone https://github.com/TeslaCloud/flux-ce.git
cd flux-ce
docker build -t flux .

# Start the server.
docker run -it --name flux -p 27015:27015/udp -p 27015:27015/tcp -v flux-sqlite:/home/steam/sqlite flux
```

You are now looking at the srcds console, which is where you run commands such as the one in [Setting yourself as admin](#setting-yourself-as-admin). Press `Ctrl+P` followed by `Ctrl+Q` to leave the console without stopping the server, and run `docker attach flux` to get back to it.

```sh
# Stop the server.
docker stop flux

# Start it again, keeping the database and all other data.
docker start -ai flux
```

The SQLite database is kept in the `flux-sqlite` volume, which outlives the container. **Everything else that the server stores, such as the data files of Flux in `garrysmod/settings/flux`, is stored inside the container.** Removing the container (`docker rm flux`) deletes it, so use `docker start` rather than a second `docker run` to bring your server back up.

The image always starts its schema. Anything you put after the image name replaces the other startup options, `+map gm_construct +maxplayers 64 -tickrate 30` (see [Starting the server](#starting-the-server)):

```sh
docker run -it --name flux -p 27015:27015/udp -p 27015:27015/tcp -v flux-sqlite:/home/steam/sqlite flux \
  +map gm_construct +maxplayers 32 -tickrate 30 +host_workshop_collection 1683881254
```

Things to keep in mind:

* Flux is copied into the image from your checkout to `garrysmod/gamemodes/hl2rp/packages/flux`. Run `docker build` again after changing the code, then create a new container.
* The dependencies, the schema and the `gmsv_file` package are cloned during the build and then cached. Add `--no-cache-filter deps,schema,gmsv_file` to `docker build` to pull in their latest versions without downloading the server again.
* To use a schema other than HL2RP, build with `--build-arg SCHEMA_REPO=https://github.com/you/your_schema.git --build-arg SCHEMA=your_schema`. The image then starts that schema.
* The image replaces the server's Lua library, `bin/linux64/lua_shared.so`, with Flux's build of it from https://data.nighty.cloud/gmod/lua_shared.so, and so does the development image below. Build with `--no-cache-filter lua_shared` to download its newest version.
* SQLite, the default database, needs no setup. To use MySQL or PostgreSQL, put a `database.yml` that points at a database server reachable from the container into a `config` folder on the host and mount it as the `config` folder of the schema's gamemode with `-v "$PWD/config:/home/steam/flux_server/garrysmod/gamemodes/hl2rp/config"` on `docker run`, see [Database setup](#database-setup).

## Docker (development)

If you are working on Flux or on a schema, use `docker-compose.yml` instead. It starts a server that runs your checkouts directly rather than a copy of them, in the `development` [environment](#environment), so the server reloads your code as you save it. The schema checkout is the gamemode and this checkout is mounted as its `flux` package. You need [fpkg](#prerequisites) on the host for the first steps.

```sh
# Flux and the schema are expected to be next to each other.
git clone https://github.com/TeslaCloud/flux-ce.git
git clone https://github.com/TeslaCloud/hl2rp.git

# Link the checkout of Flux into the packages folder of the schema.
cd hl2rp
fpkg link ../flux-ce
fpkg install
cd ../flux-ce

docker compose up                       # SQLite
docker compose --profile postgres up    # PostgreSQL
docker compose --profile mariadb up     # MariaDB
```

* The stack always runs this checkout as the `flux` package, whatever `packages/flux` of the schema checkout is. The other packages that `fpkg install` put into the schema checkout are used as they are. `gmsv_file` and `gmsv_pg`, the packages of the binary modules, are part of the image and need neither a link nor a mount: when the schema checkout does not have one of them, or has a link made by `fpkg link` for it, the container uses the copy of the image and says so when it starts. Any other package that is a link made by `fpkg link` needs a bind mount in `docker-compose.override.yml` (the comment at the top of `docker-compose.yml` shows where), and the container names the ones that are missing when it starts.
* The server is hidden from the server list. Join it with `connect localhost` (or the address of the machine) from the game console. `docker compose attach flux` opens the server console.
* The database follows the containers of the stack: the server uses PostgreSQL while the `postgres` container runs, MariaDB while the `mariadb` one does, and SQLite otherwise. Stop the stack with `docker compose --profile '*' down` before you switch to another one. The SQLite database is the `docker/sqlite/sv.db` file, everything else that the server stores is kept in Docker volumes. `docker compose down -v` deletes those.
* To use another schema, another map or another Workshop collection, set the variables listed at the top of `docker-compose.yml`, for example `FLUX_SCHEMA=reborn docker compose up`. They can also be put into an `.env` file next to it. The server downloads and mounts the Workshop collection 1683881254 unless `FLUX_WORKSHOP_COLLECTION` names another one or is empty.
* The server runs as the user ID 1000, and what it writes into your checkouts belongs to that ID. If your own user ID (`id -u`) is another one, put `FLUX_UID=<your ID>` into the `.env` file before the first `docker compose up`, or run `docker compose build` after setting it.
* To run a local build of `lua_shared.so` instead of the one in the image, bind mount it over `/home/steam/flux_server/bin/linux64/lua_shared.so` in `docker-compose.override.yml`. Mounts that only exist on your machine go into that file, which Compose merges in and Git ignores.
* The `config` folder of the schema checkout holds the configuration of the development server. Changes to it need a restart of the container. `database.local.yml` and `environment.local.lua` are written by the container and never touch your checkout.

## Installation

Flux is a package that a schema depends on: the schema is the only folder you add to `gamemodes` (Flux itself is not one), and `fpkg` installs Flux and every package it needs into the `packages` folder of the schema.

### Prerequisites

* A 64-bit Linux (x86-64) with glibc 2.35 or newer (Debian 12, Ubuntu 22.04 or newer)
* SteamCMD
* Git
* fpkg, the package manager of Flux. The ["Installing fpkg"](https://github.com/TeslaCloud/fpkg#installing-fpkg) section of its README says how to install it; the binaries are on its releases page, https://github.com/TeslaCloud/fpkg/releases.

### General installation

Run these steps in the folder that is to hold the server:

```sh
# 1. The server files. Flux requires the x86-64 branch: it only ships 64-bit modules.
steamcmd +force_install_dir "$PWD/flux_server" +login anonymous +app_update 4020 -beta x86-64 validate +quit

# 2. Flux's build of the Lua library, in place of the stock one.
curl -fL -o flux_server/bin/linux64/lua_shared.so https://data.nighty.cloud/gmod/lua_shared.so

# 3. The folder that Flux writes generated files to. It cannot create it on the first start.
mkdir -p flux_server/garrysmod/lua/_flux

# 4. The schema in the gamemodes folder (HL2RP here, or any other schema you'd like to use),
#    and its packages: Flux, everything Flux needs and the "file" binary module.
cd flux_server/garrysmod/gamemodes
git clone https://github.com/TeslaCloud/hl2rp.git
cd hl2rp
fpkg install
```

Updating or validating the server with SteamCMD can put the stock `lua_shared.so` back, so repeat step 2 after every update. A server that runs the stock library, and one where `fpkg install` has not run, only prints a message saying so when it starts.

A server that uses MySQL, MariaDB or PostgreSQL needs one more binary module, see [Binary modules](#binary-modules). Then [start the server](#starting-the-server).

The configuration of your server goes into `gamemodes/<your_schema>/config/`. A `settings.yml`, `database.yml`, `profiles.yml` or `environment.lua` there (or its `.local` variant, such as `database.local.yml`, which wins over both) is read in place of the file of the same name in `gamemodes/<your_schema>/packages/flux/config/`, which is where the defaults and their documentation are. Copy the file you want to change from there and change the copy. Never edit the files in `packages`: `fpkg` verifies them and replaces them on the next install.

#### Developing Flux or a schema

```sh
# Create a schema, or clone one.
fpkg new schema my_schema
cd my_schema

# Use your checkout of Flux instead of the published package.
fpkg link ../flux-ce

# Install the rest.
fpkg install
```

`fpkg link` makes `packages/flux` a link to the checkout. The checkout keeps its own packages in its `packages` folder, which Flux finds as well. To run the schema in a container, see [Docker (development)](#docker-development).

#### Binary modules

Flux cannot start without the `file` module, which comes with the `gmsv_file` package, a dependency of `flux`: `fpkg install` puts it into `garrysmod/lua/bin`. A PostgreSQL server needs the `pg` module: run `fpkg add gmsv_pg` in the folder of your schema, which adds `s.depends 'gmsv_pg'` to its `packagespec.lua` (or uncomments the line that schemas made with `fpkg new schema` have) and installs the module the same way. MySQLOO, the module for MySQL and MariaDB, is not an fpkg package yet: copy `gmsv_mysqloo_linux64.dll` from the [dependencies repository](https://github.com/TeslaCloud/flux-dependencies/tree/master/garrysmod/lua/bin) into `garrysmod/lua/bin` by hand.

### Starting the server

A start script you may end up with, in the `flux_server` folder:

```sh
./srcds_run_x64 +gamemode "hl2rp" +map "gm_construct" +maxplayers 64 -tickrate 30 +host_workshop_collection 1683881254
```

Clients download the Workshop content of Flux and of HL2RP when they join, but the server has to mount the models and materials of HL2RP itself, from a Workshop collection that holds them (the [HL2RP readme](https://github.com/TeslaCloud/hl2rp) lists them). `+host_workshop_collection 1683881254` mounts the collection that the development stack uses, which has them along with the Flux content and the `rp_city24_v2` map.

### Setting yourself as admin

Flux has a built-in administration solution. **Please do not attempt to install ULX as it is known to have conflicts with Flux.** Other admin mods may or may not work, we provide no official support for any other administration solutions.

Until somebody can administer the server, its console says so after every start. To become its administrator, join the server, then run the following command in the srcds console:

```
flc role set "YOUR NAME" admin
```

Replace `YOUR NAME` with your full Steam name or character name, or your full SteamID (`STEAM_0:X:Y`). The command only finds players who are on the server.

Or become a root player, who may do anything: copy `gamemodes/<your_schema>/packages/flux/config/settings.yml` to `gamemodes/<your_schema>/config/settings.yml`, put your SteamID (`STEAM_0:X:Y`) into the `bolt_root_steamid` list of the copy, such as `bolt_root_steamid: ["STEAM_0:1:12345678"]`, and restart the server.

The built-in roles are `user`, `assistant`, `gamemaster` and `admin`, each one based on the one before it. `group` and `usergroup` work in place of `role`, so `flc group set "YOUR NAME" admin` does the same thing. To take a role away again and put the player back to `user`, run the following; it also takes the SteamID of a player who is not on the server:

```
flc role remove YOUR_NAME_OR_STEAMID
```

Flux has no `setgroup` command, `flc role set` is the command that sets a role.

_The `admin` role may do anything,_ unless a permission is revoked for the player or their character in the admin menu. Root players may do anything, without exception. _Please be careful with who you give either to._

### Database setup

Depending on your use case, you may want to set up a database. SQLite is the default option and requires no further setup. It is perfect if you simply want to take a look at Flux and how it works. If you want to run Flux in production, however, you should consider setting up a MySQL (MariaDB) or PostgreSQL (14 or newer) database.

Copy `gamemodes/<your_schema>/packages/flux/config/database.yml` to `gamemodes/<your_schema>/config/database.yml` and edit the section of the copy that is named after the [environment](#environment) the server runs in, which is `production:` unless you changed it. The comments in the file explain the fields: the `adapter` is `sqlite`, `mysqloo` (or `mysql`, `mariadb`) or `pg` (or `postgres`, `postgresql`), and `port: ~` stands for the default port of the adapter. MySQL connections use utf8mb4. The adapter needs its [binary module](#binary-modules), and the database has to exist, owned by the user of `database.yml` on PostgreSQL (see [Upgrading](#upgrading) for the commands that create one).

When the server has connected, its console says which database it uses and which section of which file that comes from. A connection that fails is tried again.

### Migrations

Flux manages the database schema with migrations. A migration is a file named `<version>_<name>.lua` (the version is a `YYYYMMDDHHMMSS` timestamp) that returns a migration object describing the change:

```lua
local AddRoleToUsers = ActiveRecord.Migration.new()

function AddRoleToUsers:change()
  add_column('users', 'role', 'string', { default = "'user'" })
end

return AddRoleToUsers
```

A `default` goes into the SQL as it is: booleans and numbers are given as Lua values (`default = false`, `default = 0`), a string keeps its SQL quotes (`default = "'user'"`).

Migrations of the schema live in `gamemodes/<your_schema>/db/migrate/`. Migrations shipped with packages and plugins (their `migrations/` folders) are installed into that folder when the server starts or a task of fpkg connects to the database (see below), under a new version and the name of the plugin. Every migration that has been run is recorded in the `ar_schema_migrations` table, so each one runs exactly once; pending ones are run when the server starts. After migrating, the current state of the database is dumped into `gamemodes/<your_schema>/db/schema.lua`, which is loaded instead of the migrations when an empty database is set up. The file comes out the same whichever process dumps it, the one that ran the migrations or a later one, so it belongs in version control.

`change` is reverted automatically for `create_table`, `add_column`, `rename_column`, `rename_table`, `add_index`, `add_reference`, `add_foreign_key`, `add_timestamps` and their counterparts. Use `reversible` for anything else, or define `up` and `down` instead of `change`. The available tasks are run from the server console (`flux` alone prints them):

```
flux db:migrate [VERSION=x]                run the pending migrations, or migrate to a version
flux db:migrate:status                     list the migrations and whether they have been run
flux db:migrate:up VERSION=x               run a single migration
flux db:migrate:down VERSION=x             revert a single migration
flux db:migrate:redo [STEP=n] [VERSION=x]  revert and re-run the newest migration(s), or the one of VERSION
flux db:rollback [STEP=n]                  revert the newest migration(s)
flux db:forward [STEP=n]                   run the next pending migration(s)
flux db:version                            print the current schema version
flux db:schema:dump                        write the schema into db/schema.lua
flux db:schema:load                        create the tables of db/schema.lua
flux db:prepare                            bring the database up to date as the server does when it starts
flux db:create                             create the database (PostgreSQL only)
flux db:drop                               drop the database (PostgreSQL only)
flux generate migration AddRoleToUsers role:string
```

On PostgreSQL, `db:create` and `db:drop` connect to the `postgres` maintenance database as the user of `database.yml`: `db:create` needs a user with the right to create databases, `db:drop` the owner of the database or a superuser. Creating a database that exists and dropping one that does not only say so, so `db:drop`, `db:create` and `db:prepare` can be run again and again. PostgreSQL refuses to drop a database that another session is connected to, such as that of a running server; the task then fails with its reason.

The same tasks run from the shell without the server, through [fpkg](https://github.com/TeslaCloud/fpkg): `fpkg db:migrate`, `fpkg db:rollback STEP=2`, `fpkg generate migration AddRoleToUsers role:string` (or `fpkg g ...`) in the schema's folder, and `fpkg tasks` lists them. They boot Flux as far as the database in fpkg's own runtime, find the same migrations the server would (those of the packages and of the plugins the schema loads), and exit with 1 when they fail. `fpkg --env development db:migrate` picks the section of `database.yml` and the plugins of that environment; without `--env` the environment comes from `config/environment.lua`, as on the server. Inside a server folder (`garrysmod/gamemodes/<your_schema>`) they use the server's database: its `sv.db`, or the PostgreSQL or MySQL database of `database.yml`. In a schema checkout outside of a server they use SQLite in `<your_schema>/.fpkg/garrysmod/sv.db`, unless `--server <dir>` points fpkg at a server folder. PostgreSQL, MySQL and MariaDB work from fpkg as well, with the adapters of `database.yml` (`pg`, `postgres` or `postgresql`; `mysqloo`, `mysql` or `mariadb`): fpkg brings their modules itself, so nothing has to be installed for the tasks.

### Environment

By default, Flux comes with the `production` environment pre-chosen. It is good if you don't want to write code. If you plan on writing plugins, schemas or modifying the framework, you should set your environment to `development`. A third environment, `test`, runs like `development` and sets `IS_TEST`. If you wish to change your environment, copy the `gamemodes/<your_schema>/packages/flux/config/environment.lua` file to `gamemodes/<your_schema>/config/environment.lua` and change `production` to `development` inside that file. Any name other than these three stops the server from starting.

**What is the difference between production and development?**

In _production_, code runs a little bit faster, but it sacrifices error-tolerance and refreshability. It is perfect when you are running your server properly, because in that case you don't want to refresh the code anyway (since it causes a lot of lag).

In _development_, code runs slower, but is a lot more tolerant to errors. It uses safe mode on hooks and prints lots of useful debug information, such as load order. Due to the speed sacrifice, it is only practical to run _development_ when actually developing.

_tl;dr:_

* **production**: fast code, no refresh, _use this if you are running a server_
* **development**: slow code, yes refresh, _use this if you are developing_

## Plugins

A plugin is a folder, or a single `.lua` file whose `sv_`, `sh_` or `cl_` prefix sets its realm, in the `plugins` folder of a schema or of the `flux` package. Every plugin of the schema is loaded. The ones that come with Flux load when the `<schema>.yml` file of the schema names them, or when another loaded plugin depends on them:

* `profile` picks a named set of plugins from `config/profiles.yml` of Flux: `base`, `sandbox` (based on `base`), `roleplay` (based on `base`) or `roleplay_full` (based on `roleplay`). A `config/profiles.yml` of the schema is read after that file: a profile there replaces the one of Flux with the same ID, and the other profiles of Flux stay.
* `depends` lists plugins to load on top of the profile.
* `exclude` lists plugins of the profile to leave out. One that another loaded plugin depends on loads anyway.
* `depends_development` lists plugins to load in the `development` and `test` environments only.

A schema without `profile` loads its `depends` alone. Every other key of `<schema>.yml` is a config value that the schema sets, such as `damage_scale_head: 2`; a value changed in game wins over it. The `hl2rp.yml` of HL2RP is an example.

How to write a plugin or a schema, from its folder layout to commands, items, factions, migrations and net messages, is described in [docs/plugins.md](docs/plugins.md) of this repository. `fpkg new plugin <name>` creates a working one to start from.

## Upgrading

Pending migrations are run when the server starts (see [Migrations](#migrations)). Flux is in alpha, however, and an upgrade may change the database in ways that migrations do not cover. In that case the database has to be recreated manually.

To do that, simply follow the steps below:

1. **Stop the server.**
2. Delete the `garrysmod/gamemodes/<your_schema>/db/` folder.
3. Follow the database-specific instructions below:

### SQLite

1. Simply delete the `garrysmod/sv.db` file.
2. Start the server.

### MySQL (MariaDB / MySQL)

1. Open the MySQL console (`mysql` command on Linux) or any other means of managing your database.
2. Drop the database named in `garrysmod/gamemodes/<your_schema>/config/database[.local].yml` with `DROP DATABASE database_name_here;`, replacing `database_name_here` with that name.
3. Create it again with `CREATE DATABASE database_name_here;`.
4. Start the server.

### PostgreSQL

1. Drop the database: `sudo -u postgres dropdb database_name_here` (replace `database_name_here` with the name in your `database.yml`).
2. Create it again, owned by the user of your `database.yml`: `sudo -u postgres createdb -O user_name_here database_name_here`.
3. Start the server.

## Playing

Clients download the content addon of Flux, https://steamcommunity.com/sharedfiles/filedetails/?id=1518849094, automatically when they join, so there is nothing to install to play.

## Other info

For more info or technical support, please visit our forums: https://teslacloud.net/
