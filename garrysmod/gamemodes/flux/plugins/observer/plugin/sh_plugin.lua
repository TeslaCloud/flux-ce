PLUGIN:set_global('Observer')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

if SERVER then
  Config.set('observer_reset', false)
else
  Config.add_to_menu('general', 'observer_reset', 'config.general.observer_reset.name', 'config.general.observer_reset.desc', 'boolean')
end

function Bolt:RegisterPermissions()
  Bolt:register_permission('noclip', 'Noclip', 'Lets the player use observer mode / noclip.', 'categories.general', 'moderator')
end
