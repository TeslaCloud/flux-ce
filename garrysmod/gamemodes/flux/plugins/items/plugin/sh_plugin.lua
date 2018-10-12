PLUGIN:set_global('flItems')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')
util.include('sh_enums.lua')

function flItems:OnPluginLoaded()
  plugin.add_extra('items')
  plugin.add_extra('items/bases')

  util.include_folder(self:get_folder()..'/items/bases')
  item.IncludeItems(self:get_folder()..'/items/')
end

function flItems:PluginIncludeFolder(extra, folder)
  if extra == 'items' then
    item.IncludeItems(folder..'/items/')

    return true
  end
end
