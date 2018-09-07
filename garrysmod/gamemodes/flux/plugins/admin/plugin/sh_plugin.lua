PLUGIN:set_alias("flAdmin")

util.include("cl_hooks.lua")
util.include("sv_hooks.lua")

function flAdmin:OnPluginLoaded()
  plugin.add_extra("commands")
  plugin.add_extra("roles")

  local folder = self:get_folder()

  util.include_folder(folder.."/commands/")
  fl.admin:include_roles(folder.."/roles/")
end

function flAdmin:PluginIncludeFolder(extra, folder)
  if extra == "roles" then
    fl.admin:include_roles(folder.."/roles/")

    return true
  end
end

function flAdmin:PlayerHasPermission(player, action, object)
  return fl.admin:can(player, action, object)
end

function flAdmin:PlayerIsRoot(player)
  return player.can_anything
end
