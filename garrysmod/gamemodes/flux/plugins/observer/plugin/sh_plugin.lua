PLUGIN:set_alias("flObserver")

util.include("cl_hooks.lua")
util.include("sv_hooks.lua")

if (fl.admin) then
  fl.admin:RegisterPermission("noclip", "Noclip", "Lets the player use observer mode / noclip.", "general")
end

if SERVER then
  config.Set("observer_reset", true)
else
  config.AddToMenu("observer_reset", "Observer Reset", "Whether or not should player's position be restored when they leave observer mode?", "boolean")
end
