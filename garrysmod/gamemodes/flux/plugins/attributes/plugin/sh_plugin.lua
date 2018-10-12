PLUGIN:set_global('flAttributes')

util.include('sv_hooks.lua')

function flAttributes:PluginIncludeFolder(extra, folder)
  for k, v in pairs(attributes.types) do
    if extra == k then
      attributes.include_type(k, v, folder..'/'..k..'/')

      return true
    end
  end
end
