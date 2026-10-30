--- Shared hooks of Bolt, registered as `Bolt`: loading the role files of plugins and of the
-- schema, answering the permission and root checks of Flux, keeping players without the
-- 'context_menu' permission from using the properties of entities and from driving them,
-- registering the permissions of commands and Bolt's own permissions, the character
-- permission relation and the 'bolt_role' condition.

local hooks = {}

--- Loads the role files of a plugin when its 'roles' folder is being included.
-- @param extra [String name of the extra folder being included]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true if the folder was handled here, nothing otherwise]
function hooks:PluginIncludeFolder(extra, folder)
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
function hooks:PlayerHasPermission(actor, action, object)
  return Bolt:can(actor, action, object)
end

--- Reports whether the player was flagged as root, which happens when their SteamID is listed
-- in the bolt_root_steamid config.
-- @param target [Player]
-- @return [Boolean true for root players, nil otherwise]
function hooks:PlayerIsRoot(target)
  return target.can_anything
end

--- Keeps players without the 'context_menu' permission from using the properties of
-- entities. The gamemode only keeps them from opening the context menu, which is done on
-- the client; this is the same check where it counts, since the server asks this hook
-- before it runs a property. The decision is left to the gamemode for everybody else.
-- @param actor [Player the player using the property]
-- @param _property [String ID of the property, e.g. 'remover']
-- @param _entity [Entity the entity the property is used on]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function hooks:CanProperty(actor, _property, _entity)
  if IsValid(actor) and !actor:can('context_menu') then
    return false
  end
end

--- Keeps players without the 'context_menu' permission from driving entities, which is
-- started from the context menu. The decision is left to the gamemode for everybody else.
-- @param actor [Player the player trying to drive]
-- @param _entity [Entity the entity to be driven]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function hooks:CanDrive(actor, _entity)
  if IsValid(actor) and !actor:can('context_menu') then
    return false
  end
end

--- Registers the permissions of every command that is created. A command created once Flux
-- has loaded is also allowed to the role its `permission` field names, which
-- `Bolt:allow_command_roles` does for the others.
-- @param _id [String command ID]
-- @param data [Command command table]
function hooks:OnCommandCreated(_id, data)
  Bolt:permission_from_command(data)

  if Flux.initialized then
    Bolt:allow_command_role(data)
  end
end

--- Ties the character permission models to the `Character` model of the Characters plugin,
-- which loads after Bolt, so that the permissions of a character are loaded together
-- with it. Does nothing without the Characters plugin, or when it has been done already.
local function relate_character_permissions()
  if !istable(Character) or !isfunction(Character.has_many) then return end
  if Character.relations['character_permissions'] then return end

  CharacterPermission:belongs_to 'Character'
  CharacterTempPermission:belongs_to 'Character'
end

--- Runs the RegisterPermissions hook, then allows the commands that name a role in their
-- `permission` field to that role. Also ties the character permission models to the
-- `Character` model. After a code refresh, once the mode of CAMI is known, it is applied
-- again with `Bolt:setup_cami` for what the refresh has registered.
function hooks:OnPluginsLoaded()
  relate_character_permissions()

  --- Called on both realms once all plugins have loaded. Register permissions here with
  -- `Bolt:register_permission`. Registering a permission does not allow it for anybody: the
  -- role files allow permissions to roles with `can`.
  hook.Run('RegisterPermissions')

  Bolt:allow_command_roles()

  if Bolt.cami_mode then
    Bolt:setup_cami()
  end
end

--- Registers the 'bolt_role' condition, which compares a player's role with a chosen one.
function hooks:RegisterConditions()
  Conditions:register_condition('bolt_role', {
    name = 'condition.role.name',
    text = 'condition.role.text',
    get_args = function(panel, _data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local parameter = panel.data.role or ''

      return { operator = operator, role = parameter }
    end,
    icon = 'icon16/group.png',
    check = function(target, data)
      if !data.operator or !data.role then return false end

      return util.process_operator(data.operator, target:get_role_table().id, data.role)
    end,
    set_parameters = function(_id, data, panel, _menu, parent)
      parent:create_selector(data.name, 'condition.role.message', 'condition.roles', Bolt:get_roles(),
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

--- Registers the built-in permissions: tools, spawning, voice, context menu, noclip,
-- management of permissions, configs and plugins, and the staff / admin / super admin
-- compatibility levels.
function hooks:RegisterPermissions()
  Bolt:register_permission('physgun', nil, nil, 'permission.categories.tools')
  Bolt:register_permission('toolgun', nil, nil, 'permission.categories.tools')
  Bolt:register_permission('physgun_freeze', nil, nil, 'permission.categories.tools')
  Bolt:register_permission('physgun_pickup', nil, nil, 'permission.categories.tools')

  Bolt:register_permission('spawn_props', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_chairs', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_entities', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_vehicles', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_npcs', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_ragdolls', nil, nil, 'permission.categories.spawn')
  Bolt:register_permission('spawn_sweps', nil, nil, 'permission.categories.spawn')

  Bolt:register_permission('voice', nil, nil, 'permission.categories.general')
  Bolt:register_permission('context_menu', nil, nil, 'permission.categories.general')
  Bolt:register_permission('noclip', nil, nil, 'permission.categories.general')

  Bolt:register_permission('manage_permissions', nil, nil, 'permission.categories.player_management')
  Bolt:register_permission('manage_configuration', nil, nil, 'permission.categories.configuration')

  Bolt:register_permission('manage_plugins', nil, nil, 'permission.categories.server_management')

  Bolt:register_permission('staff', nil, nil, 'permission.categories.compatibility')
  Bolt:register_permission('moderate', nil, nil, 'permission.categories.compatibility')
  Bolt:register_permission('administrate', nil, nil, 'permission.categories.compatibility')
end

Plugin.add_hooks('Bolt', hooks)
