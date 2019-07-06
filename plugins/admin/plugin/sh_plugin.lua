PLUGIN:set_global('Bolt')

require_relative 'cl_hooks'
require_relative 'sh_enums'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

function Bolt:OnPluginLoaded()
  Plugin.add_extra('commands')
  Plugin.add_extra('roles')

  local folder = self:get_folder()

  require_relative_folder(folder..'/commands/')
  Bolt:include_roles(folder..'/roles/')
end

function Bolt:PluginIncludeFolder(extra, folder)
  if extra == 'roles' then
    Bolt:include_roles(folder..'/roles/')

    return true
  end
end

function Bolt:PlayerHasPermission(player, action, object)
  return self:can(player, action, object)
end

function Bolt:PlayerIsRoot(player)
  return player.can_anything
end

function Bolt:OnCommandCreated(id, data)
  self:permission_from_command(data)
end

function Bolt:OnPluginsLoaded()
  hook.run('RegisterPermissions')

  for k, v in pairs(self:get_roles()) do
    for k1, v1 in pairs(self:get_all_permissions()) do
      if v.role_id == v1.role then
        self:allow_children(v, k1)
      end
    end
  end
end

function Bolt:RegisterConditions()
  Conditions:register_condition('bolt_role', {
    name = 'condition.role.name',
    text = 'condition.role.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator)
      local parameter = panel.data.role

      return { operator = operator, parameter = parameter }
    end,
    icon = 'icon16/group.png',
    check = function(player, data)
      if !data.operator or !data.role then return false end

      return util.process_operator(data.operator, player:get_role(), data.role)
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

function Bolt:RegisterPermissions()
  Bolt:register_permission('physgun', 'Physgun', 'Grants access to the physics gun.', 'permission.categories.tools', 'assistant')
  Bolt:register_permission('toolgun', 'Tool Gun', 'Grants access to the tool gun.', 'permission.categories.tools', 'assistant')
  Bolt:register_permission('physgun_freeze', 'Freeze Protected Entities', 'Grants access to freeze protected entities.', 'permission.categories.tools', 'assistant')
  Bolt:register_permission('physgun_pickup', 'Unlimited Physgun', 'Grants access to pick up any entity with the physics gun.', 'permission.categories.tools', 'moderator')

  Bolt:register_permission('spawn_props', 'Spawn Props', 'Grants access to spawn props.', 'permission.categories.spawn', 'assistant')
  Bolt:register_permission('spawn_chairs', 'Spawn Chairs', 'Grants access to spawn chairs.', 'permission.categories.spawn', 'assistant')
  Bolt:register_permission('spawn_entities', 'Spawn All Entities', 'Grants access to spawn any entity.', 'permission.categories.spawn', 'assistant')
  Bolt:register_permission('spawn_vehicles', 'Spawn Vehicles', 'Grants access to spawn vehicles.', 'permission.categories.spawn', 'moderator')
  Bolt:register_permission('spawn_npcs', 'Spawn NPCs', 'Grants access to spawn NPCs.', 'permission.categories.spawn', 'moderator')
  Bolt:register_permission('spawn_ragdolls', 'Spawn Ragdolls', 'Grants access to spawn ragdolls.', 'permission.categories.spawn', 'assistant')
  Bolt:register_permission('spawn_sweps', 'Spawn SWEPs', 'Grants access to spawn scripted weapons.', 'permission.categories.spawn', 'moderator')

  Bolt:register_permission('voice', 'Voice chat access', 'Grants access to voice chat.', 'permission.categories.general')
  Bolt:register_permission('context_menu', 'Context Menu', 'Grants access to the context menu.', 'permission.categories.general', 'assistant')

  Bolt:register_permission('manage_permissions', 'Permission editor', 'Grants access to permission editor.', 'permission.categories.player_management', 'administrator')

  Bolt:register_permission('staff', 'Assistant access', 'General access for assistants.', 'permission.categories.compatibility', 'assistant')
  Bolt:register_permission('moderate', 'Admin access', 'General access for admins. Other addons will identify player as admin.', 'permission.categories.compatibility', 'moderator')
  Bolt:register_permission('administrate', 'Super Admin access', 'General access for superadmins. Other addons will identify player as superadmin.', 'permission.categories.compatibility', 'administrator')
end
