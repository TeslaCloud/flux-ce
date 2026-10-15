--- Bolt is the admin mod of Flux: roles, permissions, bans, and the commands and menus that
-- manage them.
-- Every player has a role (`user`, `assistant`, `gamemaster` or `admin` out of the box): a
-- `Role` with an immunity level and a set of allowed permissions. A permission is an ID
-- registered with `Bolt:register_permission`, normally from a `RegisterPermissions` hook;
-- every command also gets a permission named after its ID. Which roles have a permission by
-- default is up to the role files alone: each one lists the permissions it allows with `can`.
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
-- players with the plugin's commands and with the Admin entry of the tab menu, which holds
-- the player management page (role and permission editor), the staff page (everybody with a
-- role above `user`, connected or not), the ban list, the config editor and the plugin
-- manager.
--
-- Other plugins extend Bolt by registering permissions, by shipping role files in a `roles`
-- folder, and by adding pages to the admin panel from the `AddAdminMenuItems` hook. A role
-- file whose ID is already registered adds its permissions to that role, which is how a
-- plugin or schema gives the existing roles the permissions of its own commands.
-- @module [Bolt]

PLUGIN:set_global('Bolt')

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sh_enums'
require_relative 'sv_hooks'
require_relative 'sv_plugin'
require_relative 'sv_bans'
require_relative 'sv_staff'

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

--- Runs the RegisterPermissions hook.
function Bolt:OnPluginsLoaded()
  --- Called on both realms once all plugins have loaded. Register permissions here with
  -- `Bolt:register_permission`. Registering a permission does not allow it for anybody: the
  -- role files allow permissions to roles with `can`.
  hook.Run('RegisterPermissions')
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
