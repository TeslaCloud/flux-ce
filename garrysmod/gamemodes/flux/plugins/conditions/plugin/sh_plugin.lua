PLUGIN:set_global('Conditions')

local stored = Conditions.stored or {}
Conditions.stored = stored

function Conditions:register(id, data)
  stored[id] = data
end

function Conditions:get()
  return stored
end

util.include('sh_config.lua')
util.include('sv_hooks.lua')
