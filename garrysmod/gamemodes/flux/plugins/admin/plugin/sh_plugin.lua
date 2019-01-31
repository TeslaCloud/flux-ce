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
  if Conditions then
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
end
