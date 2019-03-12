PLUGIN:set_global('Items')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')
util.include('sh_enums.lua')

function Items:OnPluginLoaded()
  Plugin.add_extra('items')
  Plugin.add_extra('items/bases')

  util.include_folder(self:get_folder()..'/items/bases')
  item.include_items(self:get_folder()..'/items/')
end

function Items:PluginIncludeFolder(extra, folder)
  if extra == 'items' then
    item.include_items(folder..'/items/')

    return true
  end
end
