![Imgur](https://i.imgur.com/o4bFhLn.png)

# Flux

## What is Flux?

Flux is a WIP gamemode framework designed with performance and convenience in mind. It comes with "batteries included" and features all you need to create engaging experiences with maximum comfort. Whether you are a developer wishing to create something with Flux, or a person looking to create their own server, Flux makes it easy to achieve your goals, and gives you confidence of knowing everything will run smoothly.

## Alpha release
Current version of Flux is currently in active development as an open alpha. This means that you can install it and it will run, but there will almost inevitably be bugs and issues, as well as a lot of missing features. If you are not a developer, it is probably better for you to wait until Flux is in beta.

## Important

**Flux is only guaranteed to work on dedicated servers (srcds). We do not support "listen" servers (launching from Garry's Mod client).**

**Please read these instructions carefully. We cannot provide support if you disregard one or more steps in there instructions. Thank you!**

## Installation

Flux is a Linux-first system, which means that it is primarily designed to be installed and ran on Linux servers. Using Windows to host Flux is strongly discouraged, due to the issues and certain OS limitations.

Our installation and maintenance guides are primarily written with assumption that Flux is running under Linux. While they can be easily applied to Windows as well, we unfortunately cannot provide official support in that case.

### Prerequisites
* SteamCMD
* Git
* Linux: Debian Stretch or newer recommended (Ubuntu 16.04 will work)
* Windows: Windows 10 / Windows Server 2016+ recommended
* Windows: Microsoft Visual C++ 2015

### General installation

If you want to just get Flux up and running, clone the [dependencies repository](https://github.com/TeslaCloud/flux-dependencies). After that, simply clone repo inside of the `gamemodes` folder, as well as the [reborn schema](https://github.com/TeslaCloud/reborn) repo.

Here is approximately what you will need to do on a Linux system (you can probably do the same on Windows):
```sh
# Clone the dependencies repo into the "flux_server" folder
git clone https://github.com/TeslaCloud/flux-dependencies.git flux_server

# Then install the server files on top.
steamcmd +login anonymous +force_install_dir ./flux_server +app_update 4020 +quit

# Navigate to the gamemodes folder.
cd ./flux_server/garrysmod/gamemodes

# Clone the Flux repository as a gamemode. Make sure to clone into the "flux" folder.
git clone https://github.com/TeslaCloud/flux-ce.git flux

# Then clone the Reborn schema, or any other schema you'd like to use.
git clone https://github.com/TeslaCloud/reborn.git

# And you're all set!
```

### Creating a server startup script

Example start.sh / start.bat you may end up with:

**Linux:**
```sh
./srcds_run +gamemode "reborn" +map "gm_construct" +maxplayers 64 -tickrate 30
```

**Windows:**
```bat
srcds.exe -game garrysmod +gamemode "reborn" +map "gm_construct" +maxplayers 64 -tickrate 30
```

### Setting yourself as admin

Flux has a built-in administration solution. **Please do not attempt to install ULX as it is known to have conflicts with Flux.** Other admin mods may or may not work, we provide no official support for any other administration solutions.

Giving yourself admin rights is as simple as running the following command in the srcds console:

```
flc setgroup YOUR_NAME_OR_STEAMID admin
```

`admin` is the highest-possible user role in Flux. Replace `YOUR_NAME_OR_STEAMID` with your full or partial username or character name, or your full SteamID (`STEAM_X:X:X`).

_The `admin` role will have every single permission by default._ Similarly to the `superadmin` user role in other administration solutions, with one important difference: there are no limitations at all, and the role cannot be in any way limited. Any permission is automatically granted to all users with the `admin` role. _Please be careful with who you give this role to._

### Database setup
Depending on your use case, you may want to setup a database. SQLite is the default option and requires no further setup. It is perfect if you simply want to take a look at Flux and how it works. If you want to run Flux in production, however, you should consider setting up a MySQL (MariaDB) or PostgreSQL database.

Follow the instructions in `/garrysmod/gamemodes/flux/config/database.yml` to learn more.

### Environment
By default, Flux comes with `production` environment pre-chosen. It is good if you don't want to write code. If you plan on writing plugins, schemas or modifying the framework, you should set your environment to `development`. **No other environments are supported yet!** If you wish to change your environment, copy the `gamemodes/flux/config/environment.lua` file as `environment.local.lua` and change `production` to `development` inside that file.

**What is the difference between production and development?**

In _production_, code runs a little bit faster, but it sacrifices error-tolerance and refreshability. It it perfect when you are running your server properly, because in that case you don't want to refresh the code anyway (since it causes a lot of lag).

In _development_, code runs slower, but is a lot more tolerant to errors. It uses safe mode on hooks and print lots of useful debug information, such as load order. Due to the speed sacrifice, it is only practical to run _development_ when actually developing.

_tl;dr:_

* **production**: fast code, no refresh, _use this if you are running a server_
* **development**: slow code, yes refresh, _use this if you are developing_

## Upgrading
During Alpha, the database may break between versions. This will be different in beta and beyond, but until then, if you are upgrading Flux you need to recreate the database manually every time.

To do that, simply follow the steps below:

1. **Stop the server.**
2. Delete the `/garrysmod/gamemodes/**your_schema**/db/` folder.
3. Follow the database-specific instructions below:

### SQLite
1. Simply delete the `/garrysmod/sv.db` file.
2. Start the server.

### MariaDB (MySQL)
1. Open the MySQL console (`mysql` command on Linux) or any other means of managing your database.
2. Drop the table specified in `/garrysmod/gamemodes/flux/config/database[.local].yml`. To do that from console, simply run `DROP DATABASE database_name_here;`, replace `database_name_here` with your database name.
3. Create a new database. To do that, run `CREATE DATABASE database_name_here;`, replace `database_name_here` with your database name.
4. Start the server.

### PostgreSQL
1. Drop the database: `sudo -u postgres dropdb database_name_here` (replace `database_name_here` with your database name).
2. Re-Create the database: `sudo -u postgres createdb database_name_here`.
3. Start the server.

If you don't have access to the `postgres` user, try the same SQL as described in MySQL section, using the `psql` command.

## Playing
If you wish to play the gamemode, you should install the content addon to prevent purple-black checkers where the materials should be. You can find it here: <https://steamcommunity.com/sharedfiles/filedetails/?id=1518849094>

## Other info
For more info or technical support, please visit our forums: http://f.teslacloud.net/
