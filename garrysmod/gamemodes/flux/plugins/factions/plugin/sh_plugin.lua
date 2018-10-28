PLUGIN:set_global('flFactions')

plugin.add_extra('factions')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

function flFactions:PluginIncludeFolder(extra, folder_name)
  if extra == 'factions' then
    faction.IncludeFactions(folder_name..'/factions/')

    return true
  end
end

function flFactions:ShouldNameGenerate(player)
  if player:IsBot() then
    return false
  end
end
