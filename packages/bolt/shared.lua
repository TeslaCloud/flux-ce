--- Entry point of Bolt, the admin mod of Flux, run on both realms: roles, permissions, bans,
-- and the commands and menus that manage them. Bolt is a package, so every schema has it, and
-- it is the provider of the permission checks of Flux.
-- Every player has a role (`user`, `assistant`, `gamemaster` or `admin` out of the box): a
-- `Role` with an immunity level and a set of allowed permissions. A permission is an ID
-- registered with `Bolt:register_permission`, normally from a `RegisterPermissions` hook;
-- every command also gets a permission named after its ID. Which roles have a permission by
-- default is up to the role files: each one lists the permissions it allows with `can`. A
-- command may name a role in its `permission` field instead, which allows it to that role
-- and the roles based on it unless a role file decides the command itself; a command that
-- neither a role file nor its `permission` field allows is denied to every player.
-- Code asks whether a player may do something with `actor:can(id)`, which Bolt answers from
-- the permissions set on the player individually and those set on their active character
-- (`PERM_ALLOW` or `PERM_NEVER`, each lasting or temporary), then from their role, see
-- `Bolt:get_permission_layer`. A `PERM_NEVER` in either of them denies the permission, and
-- otherwise a `PERM_ALLOW` in either of them allows it. So one character of a player can be
-- allowed something that the role lacks, or denied something, while the player's other
-- characters are not, but no character undoes what the player is denied. The permissions of
-- a character belong to the character and apply to whoever has it loaded, such as a
-- gamemaster who plays a character that several players share. The SteamIDs listed in the
-- `bolt_root_steamid` config are root players, who may do anything.
--
-- Each role is based on the one below it and has every permission that role allows. Assistants
-- have the basic staff tools: kicking, banning, vanishing, observer mode, the physics and tool
-- guns and spawning props, and `IsAdmin` is true for them. Gamemasters also get the tools that
-- run the game world, such as spawning NPCs, vehicles and weapons, handing out items and money,
-- and managing areas, map scenes and spawn points, and `IsSuperAdmin` is true for them.
-- Administrators may do anything, including editing the configuration, permissions and
-- plugins, managing roles and restarting the server.
--
-- Bans are stored in the database and checked whenever a player connects. Staff manage
-- players with Bolt's commands, such as `/ban add|remove`, `/role set|remove`,
-- `/permission grant|revoke|reset|list`, `/charpermission grant|revoke|reset|list`,
-- `/freeze on|off`, `/kick`, `/sethealth` and `/tp`, whose 'permission', 'role', 'map' and
-- 'duration' arguments are completed while they are typed, and every player reaches the staff
-- online with `/report`. Staff also have the Admin entry of the tab menu, which holds the
-- player management page (role and permission editor, for players and their active
-- characters), the staff page (everybody with a role above `user`, connected or not), the ban
-- list, the config editor and the plugin manager.
--
-- Plugins and the schema extend Bolt by registering permissions, by shipping role files in a
-- `roles` folder, and by adding pages to the admin panel from the `AddAdminMenuItems` hook. A
-- role file whose ID is already registered adds its permissions to that role, which is how a
-- plugin or schema with several commands gives the existing roles their permissions. A
-- plugin with a single command sets the command's `permission` field instead.
--
-- Bolt speaks CAMI, the interface through which admin mods and addons share usergroups and
-- privileges, in one of two modes that the static `bolt_external_admin` config picks. Its
-- roles are CAMI usergroups in both modes: `user` is 'user' and `admin` is 'superadmin', the
-- usergroups that CAMI defines itself, `assistant` inherits from 'admin', `gamemaster` from
-- `assistant`, and every other role from the usergroup of its base role, so that
-- `GetUserGroup` is 'superadmin' for an administrator whose role (`Player:get_role_table`) is
-- `admin`. The engine's `SetUserGroup` speaks CAMI usergroups as well: 'admin' gives
-- `assistant` and 'superadmin' gives `admin`, so that an addon that passes 'admin' never grants
-- full administration, while Bolt sets roles by their ID with `Player:set_role_id`. By
-- default Bolt is the admin mod of the server: the usergroups and privileges that other addons
-- register become Bolt roles and permissions (a privilege is allowed to `user`, `assistant` or
-- `admin` as its minimum access is 'user', 'admin' or 'superadmin'), and Bolt answers CAMI's
-- access checks for the permissions it knows. With `bolt_external_admin` on, another admin
-- mod owns and stores the usergroups: Bolt registers its permissions as privileges and leaves
-- the engine's usergroup methods to that admin mod, so setting a player's usergroup, as Bolt's
-- own role changes also do, changes nothing but the engine's usergroup and Bolt saves no role
-- for it. Root access and the permissions set on the player and their character still decide
-- first, and CAMI is asked in place of the role. Either way, Bolt signals the role changes it
-- makes to CAMI under the usergroups of the roles, and bans, commands and the admin panel work
-- the same in both modes. See `lib/sh_cami.lua`.
--
-- The package loads its libraries, classes and player extensions, its configs, the models and
-- the admin panel, then the hooks and the network handlers, so that its own commands, which
-- follow, get their permissions from the `CommandCreated` handler. Then it adds 'roles' to
-- the extra folders of plugins and loads its own roles. On the server it also registers the
-- package's languages and migrations with `Pipeline`. During a partial code reload
-- (`LITE_REFRESH`) nothing is loaded again.
-- @module [Bolt]

if !LITE_REFRESH then
  local package_path = PACKAGE.__path__

  require_relative_folder('lib', true)
  require_relative_folder('lib/classes', true)
  require_relative_folder('lib/meta', true)

  Config.include_folder(package_path..'config')

  if SERVER then
    Pipeline.include_folder('language', package_path..'languages')
    Pipeline.include_folder('migrations', package_path..'migrations')
  end

  require_relative_folder('models', true)
  require_relative_folder('views', true)
  require_relative_folder('hooks', true)
  require_relative_folder('nethooks', true)

  Pipeline.include_folder('commands', package_path..'commands')

  Plugin.add_extra('roles')
  Bolt:include_roles(package_path..'roles')
end
