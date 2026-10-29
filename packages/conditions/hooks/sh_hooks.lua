--- Shared hooks of the Conditions package, registered as `Conditions`: collecting the
-- condition types of the plugins once they have loaded.

local hooks = {}

--- Runs the RegisterConditions hook so that plugins can register their condition types.
function hooks:OnPluginsLoaded()
  --- Lets plugins register their condition types with `Conditions:register_condition`. Called
  -- on the server and the client once all plugins have been loaded. Do not return anything
  -- from the handler, or the plugins after it are not asked.
  hook.Run('RegisterConditions')
end

Plugin.add_hooks('Conditions', hooks)
