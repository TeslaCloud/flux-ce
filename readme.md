![Imgur](https://i.imgur.com/o4bFhLn.png)

# Flux

## What is Flux?

Flux is a WIP gamemode framework designed with performance and convenience in mind. It comes with "batteries included" and features all you need to create engaging experiences with maximum comfort. Whether you are a developer wishing to create something with Flux, or a person looking to create their own server, Flux makes it easy to achieve your goals, and gives you the confidence of knowing everything will run smoothly.

## Development Version

The current version of Flux is currently in active development. This means that you can install it and it will run, but there will almost inevitably be bugs and issues, as well as a lot of missing features. If you are not a developer, it is probably better for you to wait until Flux is in beta.

## Important

**Flux is only guaranteed to work on dedicated servers (srcds). We do not support "listen" servers (launching from the Garry's Mod client).**

**Please read these instructions carefully. We cannot provide support if you disregard one or more steps in these instructions. Thank you!**

## Docker (easy mode)

If you have Docker and simply want a running server, you can skip the installation guide below. The `Dockerfile` in this repository performs the steps from [General installation](#general-installation) for you: it installs the x86-64 Garry's Mod dedicated server, the binary modules, the HL2RP schema as the gamemode and this checkout as its `flux` package.

```sh
# Clone the Flux repository and build the image.
# This downloads the dedicated server (about 7 GB), so it will take a while.
git clone https://github.com/TeslaCloud/flux-ce.git
cd flux-ce
docker build -t flux .

# Start the server.
docker run -it --name flux -p 27015:27015/udp -p 27015:27015/tcp flux
```

You are now looking at the srcds console, which is where you run commands such as the one in [Setting yourself as admin](#setting-yourself-as-admin). Press `Ctrl+P` followed by `Ctrl+Q` to leave the console without stopping the server, and run `docker attach flux` to get back to it.

```sh
# Stop the server.
docker stop flux

# Start it again, keeping the database and all other data.
docker start -ai flux
```

**The database and all other server data are stored inside the container.** Removing the container (`docker rm flux`) deletes them, so use `docker start` rather than a second `docker run` to bring your server back up.

Anything you put after the image name replaces the default startup options (see [Creating a server startup script](#creating-a-server-startup-script)):

```sh
docker run -it --name flux -p 27015:27015/udp -p 27015:27015/tcp flux \
  +gamemode "hl2rp" +map "gm_flatgrass" +maxplayers 32 -tickrate 30
```

Things to keep in mind:

* Flux is copied into the image from your checkout to `garrysmod/gamemodes/hl2rp/packages/flux`. Run `docker build` again after changing the code, then create a new container.
* The dependencies, the schema and the `gmsv_file` package are cloned during the build and then cached. Add `--no-cache-filter deps,schema,gmsv_file` to `docker build` to pull in their latest versions without downloading the server again.
* To use a schema other than HL2RP, build with `--build-arg SCHEMA_REPO=https://github.com/you/your_schema.git --build-arg SCHEMA=your_schema` and pass `+gamemode your_schema`.
* The image replaces the server's Lua library, `bin/linux64/lua_shared.so`, with Flux's build of it from https://data.nighty.cloud/gmod/lua_shared.so, and so does the development image below. Build with `--build-arg LUA_SHARED_URL=` to keep the stock library, or with `--no-cache-filter lua_shared` to download its newest version.
* SQLite, the default database, needs no setup. To use MySQL or PostgreSQL, put a `database.yml` that points at a database server reachable from the container into a `config` folder on the host and mount it as the `config` folder of the schema's gamemode with `-v "$PWD/config:/home/steam/flux_server/garrysmod/gamemodes/hl2rp/config"` on `docker run`, see [Database setup](#database-setup).

## Docker (development)

If you are working on Flux or on a schema, use `docker-compose.yml` instead. It starts a server that runs your checkouts directly rather than a copy of them, in the `development` [environment](#environment), so the server reloads your code as you save it. The schema checkout is the gamemode and this checkout is mounted as its `flux` package.

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
* The database is picked by the profile, there is nothing to configure. The SQLite database is the `docker/sqlite/sv.db` file, everything else that the server stores is kept in Docker volumes. `docker compose down -v` deletes those.
* To use another schema, another map or a Workshop collection, set the variables listed at the top of `docker-compose.yml`, for example `FLUX_SCHEMA=reborn docker compose up`. They can also be put into an `.env` file.
* The server runs a local build of `lua_shared.so` when `FLUX_LUA_SHARED` points to one, instead of the build in the image. Mounts that only exist on your machine go into `docker-compose.override.yml`, which Compose merges in and Git ignores.
* The `config` folder of the schema checkout holds the configuration of the development server. Changes to it need a restart of the container. `database.local.yml` and `environment.local.lua` are written by the container and never touch your checkout.

## Installation

Flux is a Linux-first system, which means that it is primarily designed to be installed and run on Linux servers. Using Windows to host Flux is strongly discouraged, due to issues and certain OS limitations.

Our installation and maintenance guides are primarily written with the assumption that Flux is running under Linux. While they can be easily applied to Windows as well, we unfortunately cannot provide official support in that case.

### Prerequisites

* SteamCMD
* Git
* [fpkg](https://fluxpkg.dev), the package manager of Flux
* The `x86-64` branch of the Garry's Mod dedicated server. Flux only ships 64-bit modules, so the default 32-bit server will not work.
* Linux: a 64-bit distribution with glibc 2.35 or newer (Debian 12, Ubuntu 22.04 or newer)
* Windows: Windows 10 / Windows Server 2016+ recommended
* Windows: Microsoft Visual C++ 2015

### General installation

Flux is a package that a schema depends on: the schema is the only folder you add to `gamemodes` (Flux itself is not one), and `fpkg` installs Flux and every package it needs into the `packages` folder of the schema. The binary modules come from the [dependencies repository](https://github.com/TeslaCloud/flux-dependencies), see [Binary modules](#binary-modules).

Here is approximately what you will need to do on a Linux system (you can probably do the same on Windows):
```sh
# Clone the dependencies repo into the "flux_server" folder
git clone https://github.com/TeslaCloud/flux-dependencies.git flux_server

# Then install the server files on top. Flux requires the x86-64 branch.
steamcmd +login anonymous +force_install_dir ./flux_server +app_update 4020 -beta x86-64 validate +quit

# Put the Reborn schema, or any other schema you'd like to use, into the gamemodes folder.
cd ./flux_server/garrysmod/gamemodes
git clone https://github.com/TeslaCloud/reborn.git

# Install Flux and the other packages of the schema. fpkg finds the schema from any
# folder of the server.
fpkg install

# And you're all set!
```

The configuration of your server goes into `gamemodes/<your_schema>/config/`. A `settings.yml`, `database.yml`, `profiles.yml` or `environment.lua` there (or its `.local` variant, such as `database.local.yml`) is read in place of the file of the same name in `gamemodes/<your_schema>/packages/flux/config/`, which is where the defaults and their documentation are. Never edit the files in `packages`: `fpkg` verifies them and replaces them on the next install.

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

Flux cannot start without the `file` module, which comes with the `gmsv_file` package, a dependency of `flux`: `fpkg install` puts it into `garrysmod/lua/bin`. A PostgreSQL server needs the `pg` module: uncomment `s.depends 'gmsv_pg'` in the `packagespec.lua` of your schema and run `fpkg install`. MySQLOO, the module for MySQL and MariaDB, is not an fpkg package yet: copy it from the [dependencies repository](https://github.com/TeslaCloud/flux-dependencies) into `garrysmod/lua/bin` by hand.

### Creating a server startup script

Example start.sh / start.bat you may end up with:

**Linux:**
```sh
./srcds_run_x64 +gamemode "reborn" +map "gm_construct" +maxplayers 64 -tickrate 30
```

**Windows:**
```bat
srcds_win64.exe -game garrysmod +gamemode "reborn" +map "gm_construct" +maxplayers 64 -tickrate 30
```

### Setting yourself as admin

Flux has a built-in administration solution. **Please do not attempt to install ULX as it is known to have conflicts with Flux.** Other admin mods may or may not work, we provide no official support for any other administration solutions.

Giving yourself admin rights is as simple as running the following command in the srcds console:

```
flc role set YOUR_NAME_OR_STEAMID admin
```

`admin` is the highest-possible user role in Flux. Replace `YOUR_NAME_OR_STEAMID` with your full Steam name or character name (in double quotes if it has spaces in it), or your full SteamID (`STEAM_X:X:X`).

The built-in roles are `user`, `assistant`, `gamemaster` and `admin`, each one based on the one before it. `group` and `usergroup` work in place of `role`, so `flc group set YOUR_NAME_OR_STEAMID admin` does the same thing. To take a role away again and put the player back to `user`, run:

```
flc role remove YOUR_NAME_OR_STEAMID
```

Flux has no `setgroup` command, `flc role set` is the command that sets a role.

_The `admin` role will have every single permission by default._ Similarly to the `superadmin` user role in other administration solutions, with one important difference: there are no limitations at all, and the role cannot be in any way limited. Any permission is automatically granted to all users with the `admin` role. _Please be careful with who you give this role to._

### Database setup

Depending on your use case, you may want to set up a database. SQLite is the default option and requires no further setup. It is perfect if you simply want to take a look at Flux and how it works. If you want to run Flux in production, however, you should consider setting up a MySQL (MariaDB) or PostgreSQL database.

Follow the instructions in `/garrysmod/gamemodes/<your_schema>/packages/flux/config/database.yml` to learn more. Copy that file to `/garrysmod/gamemodes/<your_schema>/config/database.yml` and change the copy.

### Migrations

Flux manages the database schema with migrations. A migration is a file named `<version>_<name>.lua` (the version is a `YYYYMMDDHHMMSS` timestamp) that returns a migration object describing the change:

```lua
local AddRoleToUsers = ActiveRecord.Migration.new()

function AddRoleToUsers:change()
  add_column('users', 'role', 'string', { default = "'user'" })
end

return AddRoleToUsers
```

Migrations of the schema live in `gamemodes/<your_schema>/db/migrate/`. Migrations shipped with packages and plugins (their `migrations/` folders) are installed into that folder when the server starts, under a new version and the name of the plugin. Every migration that has been run is recorded in the `ar_schema_migrations` table, so each one runs exactly once; pending ones are run when the server starts. After migrating, the current state of the database is dumped into `gamemodes/<your_schema>/db/schema.lua`, which is loaded instead of the migrations when an empty database is set up.

`change` is reverted automatically for `create_table`, `add_column`, `rename_column`, `rename_table`, `add_index`, `add_reference`, `add_foreign_key`, `add_timestamps` and their counterparts. Use `reversible` for anything else, or define `up` and `down` instead of `change`. The available tasks are run from the server console:

```
flux db:migrate [VERSION=x]       run the pending migrations, or migrate to a version
flux db:migrate:status            list the migrations and whether they have been run
flux db:migrate:up VERSION=x      run a single migration
flux db:migrate:down VERSION=x    revert a single migration
flux db:migrate:redo [STEP=n]     revert and re-run the newest migration(s)
flux db:rollback [STEP=n]         revert the newest migration(s)
flux db:forward [STEP=n]          run the next pending migration(s)
flux db:version                   print the current schema version
flux db:schema:dump               write the schema into db/schema.lua
flux db:schema:load               create the tables of db/schema.lua
flux generate migration AddRoleToUsers role:string
```

### Environment

By default, Flux comes with the `production` environment pre-chosen. It is good if you don't want to write code. If you plan on writing plugins, schemas or modifying the framework, you should set your environment to `development`. A third environment, `test`, runs like `development` and sets `IS_TEST`. If you wish to change your environment, copy the `gamemodes/<your_schema>/packages/flux/config/environment.lua` file to `gamemodes/<your_schema>/config/environment.lua` and change `production` to `development` inside that file.

**What is the difference between production and development?**

In _production_, code runs a little bit faster, but it sacrifices error-tolerance and refreshability. It is perfect when you are running your server properly, because in that case you don't want to refresh the code anyway (since it causes a lot of lag).

In _development_, code runs slower, but is a lot more tolerant to errors. It uses safe mode on hooks and prints lots of useful debug information, such as load order. Due to the speed sacrifice, it is only practical to run _development_ when actually developing.

_tl;dr:_

* **production**: fast code, no refresh, _use this if you are running a server_
* **development**: slow code, yes refresh, _use this if you are developing_

## Plugins

A plugin is a folder (or a single `.lua` file, whose `sv_`, `sh_` or `cl_` prefix sets its realm) in the `plugins` folder of the `flux` package or in the `plugins` folder of a schema. All plugins of the schema are loaded, the ones that come with Flux only when the schema or another plugin lists them under `depends`. A plugin folder looks like this:

```
plugins/doors/
  plugin.yml          name, description, author, version, depends
  plugin/
    sh_plugin.lua     main file
    cl_plugin.lua
    sv_plugin.lua
    cl_hooks.lua      hook handlers
    sh_hooks.lua
    sv_hooks.lua
    lib/              libraries and modules
    nethooks/         network message handlers, such as sv_doors.lua
    config/  languages/  views/  tools/  entities/  migrations/  ...
```

The root of the `plugin` folder only holds these Lua files, and a plugin only has the ones it needs. The main file may also be named `sh_<name>.lua` after the `name` in `plugin.yml`, or after the folder when `plugin.yml` has no name. Flux includes the main file, which includes the other root files with `require_relative`. Everything else goes into `lib/`, written as a library or module, or into one of the folders that Flux includes by convention: `lib/meta`, `lib/classes`, `models`, `classes`, `meta`, `config`, `languages`, `controllers`, `views`, `tools`, `themes`, `entities`, `migrations` and `nethooks`, which holds the `Cable.receive` and `MVC.handler` registrations in files named after their topic, as well as the folders that plugins add, such as `commands`, `items`, `factions`, `roles`, `attributes` and `skills`.

These folders are included before the main file, `lib` first. The files of a folder are included in alphabetical order, each in the realm that its `cl_`, `sh_` or `sv_` prefix names. A library therefore sets up the global it extends itself and does not rely on anything that the main file sets up while it loads.

A schema follows the same layout in its `schema` folder, with `sh_schema.lua`, `cl_schema.lua` and `sv_schema.lua` in place of the `*_plugin.lua` files. Unlike a plugin's main file, `sh_schema.lua` is included before the folders of the schema.

## Upgrading

Pending migrations are run when the server starts (see [Migrations](#migrations)). Flux is in alpha, however, and an upgrade may change the database in ways that migrations do not cover. In that case the database has to be recreated manually.

To do that, simply follow the steps below:

1. **Stop the server.**
2. Delete the `/garrysmod/gamemodes/**your_schema**/db/` folder.
3. Follow the database-specific instructions below:

### SQLite

1. Simply delete the `/garrysmod/sv.db` file.
2. Start the server.

### MySQL (MariaDB / MySQL)

1. Open the MySQL console (`mysql` command on Linux) or any other means of managing your database.
2. Drop the table specified in `/garrysmod/gamemodes/**your_schema**/config/database[.local].yml`. To do that from the console, simply run `DROP DATABASE database_name_here;`, replace `database_name_here` with your database name.
3. Create a new database. To do that, run `CREATE DATABASE database_name_here;`, replace `database_name_here` with your database name.
4. Start the server.

### PostgreSQL

1. Drop the database: `sudo -u postgres dropdb database_name_here` (replace `database_name_here` with your database name).
2. Re-Create the database: `sudo -u postgres createdb database_name_here`.
3. Start the server.

If you don't have access to the `postgres` user, try the same SQL as described in the MySQL section, using the `psql` command.

## Playing

If you wish to play the gamemode, you should install the content addon to prevent purple-black checkers where the materials should be. You can find it here: <https://steamcommunity.com/sharedfiles/filedetails/?id=1518849094>

## Other info

For more info or technical support, please visit our forums: https://teslacloud.net/
