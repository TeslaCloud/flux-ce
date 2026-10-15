--- Bolt is the admin mod of Flux: roles, permissions, bans, and the commands and menus that
-- manage them.
-- Every player has a role (`user`, `assistant`, `gamemaster` or `admin` out of the box): a
-- `Role` with an immunity level and a set of allowed permissions. A permission is an ID
-- registered with `Bolt:register_permission`, normally from a `RegisterPermissions` hook;
-- every command also gets a permission named after its ID. Which roles have a permission by
-- default is up to the role files: each one lists the permissions it allows with `can`. A
-- command may name a role in its `permission` field instead, which allows it to that role
-- and the roles based on it unless a role file decides the command itself; a command that
-- neither a role file nor its `permission` field allows is denied to every player.
-- Code asks whether a player may do something with `actor:can(id)`, which Bolt answers from
-- the player's unexpired temporary permissions, then their individual permissions
-- (`PERM_ALLOW` or `PERM_NEVER`), then their role. The SteamIDs listed in the `root_steamid`
-- config are root players, who may do anything.
--
-- Each role is based on the one below it and has every permission that role allows. Assistants
-- have the basic staff tools: kicking, banning, vanishing, observer mode, the physics and tool
-- guns and spawning props, and other addons see them as admins. Gamemasters also get the
-- tools that run the game world, such as spawning NPCs, vehicles and weapons, handing out
-- items and money, and managing areas, map scenes and spawn points, and other addons see
-- them as super admins. Administrators may do anything, including editing the configuration,
-- permissions and plugins, managing roles and restarting the server.
--
-- Bans are stored in the database and checked whenever a player connects. Staff manage
-- players with the plugin's commands, such as `/ban add|remove`, `/role set|remove`,
-- `/permission grant|revoke|reset|list`, `/freeze on|off`, `/kick` and `/tp`, whose
-- 'permission', 'role', 'map' and 'duration' arguments are completed while they are typed.
-- They also have the Admin entry of the tab menu, which holds the player management page
-- (role and permission editor), the staff page (everybody with a role above `user`,
-- connected or not), the ban list, the config editor and the plugin manager.
--
-- Other plugins extend Bolt by registering permissions, by shipping role files in a `roles`
-- folder, and by adding pages to the admin panel from the `AddAdminMenuItems` hook. A role
-- file whose ID is already registered adds its permissions to that role, which is how a
-- plugin or schema with several commands gives the existing roles their permissions. A
-- plugin with a single command sets the command's `permission` field instead.
-- @module [Bolt]

PLUGIN:set_global('Bolt')

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sh_enums'
require_relative 'sv_hooks'
require_relative 'sv_plugin'
require_relative 'sv_bans'
require_relative 'sv_staff'

local duration_examples = { '30', '1 hour', '1 day', '1 week', '1 month', 'perma' }

--- Suggests a few durations for the arguments of the 'duration' type, which are read with
-- `Bolt:interpret_ban_time`: a bare number is minutes, and 'perma' stands for a permanent
-- duration.
-- @return [List<String>]
local function complete_duration()
  return duration_examples
end

--- Lists the IDs of every registered permission for the arguments of the 'permission' type.
-- @return [List<String> permission IDs, sorted]
local function complete_permission()
  local ids = {}

  for id in pairs(Bolt:get_all_permissions()) do
    ids[#ids + 1] = id
  end

  table.sort(ids)

  return ids
end

--- Lists the IDs of every registered role for the arguments of the 'role' type.
-- @return [List<String> role IDs, sorted]
local function complete_role()
  local ids = {}

  for id in pairs(Bolt:get_roles()) do
    ids[#ids + 1] = id
  end

  table.sort(ids)

  return ids
end

--- Lists the maps for the arguments of the 'map' type, see `Bolt:get_maps`.
-- @return [List<String> map names]
local function complete_map()
  return Bolt:get_maps()
end

Flux.Command:add_completer('duration', complete_duration)
Flux.Command:add_completer('permission', complete_permission)
Flux.Command:add_completer('role', complete_role)
Flux.Command:add_completer('map', complete_map)

--- Registers 'roles' as a plugin folder type and loads the admin plugin's own roles.
function Bolt:OnPluginLoaded()
  Plugin.add_extra('roles')
  Bolt:include_roles(self:get_folder()..'/roles/')
end

--- Loads the role files of a plugin when its 'roles' folder is being included.
-- @param extra [String name of the extra folder being included]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true if the folder was handled here, nothing otherwise]
function Bolt:PluginIncludeFolder(extra, folder)
  if extra == 'roles' then
    Bolt:include_roles(folder..'/roles/')

    return true
  end
end

--- Answers the permission checks made through actor:can by delegating to Bolt:can.
-- @param actor [Player]
-- @param action [String permission ID]
-- @param object=nil [String object name the permission was allowed for]
-- @return [Boolean]
function Bolt:PlayerHasPermission(actor, action, object)
  return self:can(actor, action, object)
end

--- Reports whether the player was flagged as root, which happens when their SteamID is listed
-- in the root_steamid config.
-- @param target [Player]
-- @return [Boolean true for root players, nil otherwise]
function Bolt:PlayerIsRoot(target)
  return target.can_anything
end

--- Keeps players without the 'context_menu' permission from using the properties of
-- entities. The gamemode only keeps them from opening the context menu, which is done on
-- the client; this is the same check where it counts, since the server asks this hook
-- before it runs a property. The decision is left to the gamemode for everybody else.
-- @param actor [Player the player using the property]
-- @param property [String ID of the property, e.g. 'remover']
-- @param entity [Entity the entity the property is used on]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function Bolt:CanProperty(actor, property, entity)
  if IsValid(actor) and !actor:can('context_menu') then
    return false
  end
end

--- Keeps players without the 'context_menu' permission from driving entities, which is
-- started from the context menu. The decision is left to the gamemode for everybody else.
-- @param actor [Player the player trying to drive]
-- @param entity [Entity the entity to be driven]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function Bolt:CanDrive(actor, entity)
  if IsValid(actor) and !actor:can('context_menu') then
    return false
  end
end

--- Registers a permission for every newly created command.
-- @param id [String command ID]
-- @param data [Command command table]
function Bolt:OnCommandCreated(id, data)
  self:permission_from_command(data)
end

--- Runs the RegisterPermissions hook, then allows the commands that name a role in their
-- `permission` field to that role.
function Bolt:OnPluginsLoaded()
  --- Called on both realms once all plugins have loaded. Register permissions here with
  -- `Bolt:register_permission`. Registering a permission does not allow it for anybody: the
  -- role files allow permissions to roles with `can`.
  hook.Run('RegisterPermissions')

  self:allow_command_roles()
end

--- Registers the 'bolt_role' condition, which compares a player's role with a chosen one.
function Bolt:RegisterConditions()
  Conditions:register_condition('bolt_role', {
    name = 'condition.role.name',
    text = 'condition.role.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator)
      local parameter = panel.data.role

      return { operator = operator, role = parameter }
    end,
    icon = 'icon16/group.png',
    check = function(target, data)
      if !data.operator or !data.role then return false end

      return util.process_operator(data.operator, target:get_role(), data.role)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'condition.role.message', 'condition.roles', self:get_roles(),
      function(selector, group)
        selector:add_choice(t(group.name), function()
          panel.data.role = group.id

          panel.update()
        end)
      end)
    end,
    set_operator = 'equal'
  })
end

--- Registers the built-in permissions: tools, spawning, voice, context menu, management of
-- permissions, configs and plugins, and the staff / admin / super admin compatibility
-- levels.
function Bolt:RegisterPermissions()
  Bolt:register_permission(
    'physgun',
    'Physgun',
    'Grants access to the physics gun.',
    'permission.categories.tools'
  )
  Bolt:register_permission(
    'toolgun',
    'Tool Gun',
    'Grants access to the tool gun.',
    'permission.categories.tools'
  )
  Bolt:register_permission(
    'physgun_freeze',
    'Freeze Protected Entities',
    'Grants access to freeze protected entities.',
    'permission.categories.tools'
  )
  Bolt:register_permission(
    'physgun_pickup',
    'Unlimited Physgun',
    'Grants access to pick up any entity with the physics gun.',
    'permission.categories.tools'
  )

  Bolt:register_permission(
    'spawn_props',
    'Spawn Props',
    'Grants access to spawn props.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_chairs',
    'Spawn Chairs',
    'Grants access to spawn chairs.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_entities',
    'Spawn All Entities',
    'Grants access to spawn any entity.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_vehicles',
    'Spawn Vehicles',
    'Grants access to spawn vehicles.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_npcs',
    'Spawn NPCs',
    'Grants access to spawn NPCs.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_ragdolls',
    'Spawn Ragdolls',
    'Grants access to spawn ragdolls.',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'spawn_sweps',
    'Spawn SWEPs',
    'Grants access to spawn scripted weapons.',
    'permission.categories.spawn'
  )

  Bolt:register_permission(
    'voice',
    'Voice chat access',
    'Grants access to voice chat.',
    'permission.categories.general'
  )
  Bolt:register_permission(
    'context_menu',
    'Context Menu',
    'Grants access to the context menu, to the properties of entities and to driving them.',
    'permission.categories.general'
  )

  Bolt:register_permission(
    'manage_permissions',
    'Permission editor',
    'Grants access to the permission editor.',
    'permission.categories.player_management'
  )
  Bolt:register_permission(
    'manage_configuration',
    'Configuration',
    'Grants access to configuration.',
    'permission.categories.configuration'
  )

  Bolt:register_permission(
    'manage_plugins',
    'permission.manage_plugins.name',
    'permission.manage_plugins.description',
    'permission.categories.server_management'
  )

  Bolt:register_permission(
    'staff',
    'Assistant access',
    'Marks the player as a member of the staff.',
    'permission.categories.compatibility'
  )
  Bolt:register_permission(
    'moderate',
    'Admin access',
    'General staff access. Other addons identify the player as an admin.',
    'permission.categories.compatibility'
  )
  Bolt:register_permission(
    'administrate',
    'Super Admin access',
    'Advanced staff access. Other addons identify the player as a superadmin.',
    'permission.categories.compatibility'
  )
end
