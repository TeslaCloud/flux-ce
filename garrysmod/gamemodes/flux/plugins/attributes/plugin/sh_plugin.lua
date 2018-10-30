PLUGIN:set_global('Attributes')

util.include('sv_hooks.lua')

function Attributes:PluginIncludeFolder(extra, folder)
  for k, v in pairs(attributes.types) do
    if extra == k then
      attributes.include_type(k, v, folder..'/'..k..'/')

      return true
    end
  end
end
