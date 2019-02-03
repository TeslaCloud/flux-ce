PLUGIN:set_global('Bolt')

util.include('cl_hooks.lua')
util.include('sh_enums.lua')
util.include('sv_hooks.lua')
util.include('sv_plugin.lua')

function Bolt:OnPluginLoaded()
  plugin.add_extra('commands')
  plugin.add_extra('roles')

  local folder = self:get_folder()

  util.include_folder(folder..'/commands/')
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
        self:allow_childs(v, k1)
      end
    end
  end
end

function Bolt:RegisterConditions()
  Conditions:register_condition('bolt_role', {
    name = 'conditions.role.name',
    text = 'conditions.role.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator)
      local parameter = panel.data.role

      return { operator, parameter }
    end,
    icon = 'icon16/group.png',
    check = function(player, data)
      if !data.operator or !data.role then return false end

      return util.process_operator(data.operator, player:get_role(), data.role)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'conditions.role.message', 'conditions.roles', self:get_roles(), 
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
  Bolt:register_permission('physgun', 'Physgun', 'Grants access to the physics gun.', 'categories.tools', 'assistant')
  Bolt:register_permission('toolgun', 'Tool Gun', 'Grants access to the tool gun.', 'categories.tools', 'assistant')
  Bolt:register_permission('physgun_freeze', 'Freeze Protected Entities', 'Grants access to freeze protected entities.', 'categories.tools', 'assistant')
  Bolt:register_permission('physgun_pickup', 'Unlimited Physgun', 'Grants access to pick up any entity with the physics gun.', 'categories.tools', 'moderator')

  Bolt:register_permission('spawn_props', 'Spawn Props', 'Grants access to spawn props.', 'categories.spawn', 'assistant')
  Bolt:register_permission('spawn_chairs', 'Spawn Chairs', 'Grants access to spawn chairs.', 'categories.spawn', 'assistant')
  Bolt:register_permission('spawn_entities', 'Spawn All Entities', 'Grants access to spawn any entity.', 'categories.spawn', 'assistant')
  Bolt:register_permission('spawn_vehicles', 'Spawn Vehicles', 'Grants access to spawn vehicles.', 'categories.spawn', 'moderator')
  Bolt:register_permission('spawn_npcs', 'Spawn NPCs', 'Grants access to spawn NPCs.', 'categories.spawn', 'moderator')
  Bolt:register_permission('spawn_ragdolls', 'Spawn Ragdolls', 'Grants access to spawn ragdolls.', 'categories.spawn', 'assistant')
  Bolt:register_permission('spawn_sweps', 'Spawn SWEPs', 'Grants access to spawn scripted weapons.', 'categories.spawn', 'moderator')

  Bolt:register_permission('voice', 'Voice chat access', 'Grants access to voice chat.', 'categories.general')
  Bolt:register_permission('context_menu', 'Context Menu', 'Grants access to the context menu.', 'categories.general', 'assistant')

  Bolt:register_permission('manage_permissions', 'Permission editor', 'Grants access to permission editor.', 'categories.player_management', 'administrator')
end
