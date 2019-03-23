PLUGIN:set_global('Conditions')

local stored = Conditions.stored or {}
Conditions.stored = stored

function Conditions:register_condition(id, data)
  stored[id] = data
end

function Conditions:get_all()
  return stored
end

require_relative 'sh_config'
require_relative 'sv_plugin'

function Conditions:OnPluginsLoaded()
  hook.run('RegisterConditions')
end
