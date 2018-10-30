PLUGIN:set_global('Bolt')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

function Bolt:OnPluginLoaded()
  plugin.add_extra('commands')
  plugin.add_extra('roles')

  local folder = self:get_folder()

  util.include_folder(folder..'/commands/')
  fl.admin:include_roles(folder..'/roles/')
end

function Bolt:PluginIncludeFolder(extra, folder)
  if extra == 'roles' then
    fl.admin:include_roles(folder..'/roles/')

    return true
  end
end

function Bolt:PlayerHasPermission(player, action, object)
  return fl.admin:can(player, action, object)
end

function Bolt:PlayerIsRoot(player)
  return player.can_anything
end
