PLUGIN:set_global('Items')

require_relative('cl_hooks.lua')
require_relative('sv_hooks.lua')
require_relative('sh_enums.lua')

function Items:OnPluginLoaded()
  Plugin.add_extra('items')
  Plugin.add_extra('items/bases')

  require_relative_folder(self:get_folder()..'/items/bases')
  Item.include_items(self:get_folder()..'/items/')
end

function Items:PluginIncludeFolder(extra, folder)
  if extra == 'items' then
    Item.include_items(folder..'/items/')

    return true
  end
end
