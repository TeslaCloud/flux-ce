PLUGIN:set_global('Items')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
require_relative 'sh_enums'

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
