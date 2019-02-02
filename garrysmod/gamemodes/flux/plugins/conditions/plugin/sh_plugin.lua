PLUGIN:set_global('Conditions')

local stored = Conditions.stored or {}
Conditions.stored = stored

function Conditions:register_condition(id, data)
  stored[id] = data
end

function Conditions:get_all()
  return stored
end

util.include('sh_config.lua')
util.include('sv_plugin.lua')

function Conditions:OnPluginsLoaded()
  hook.run('RegisterConditions')
end
