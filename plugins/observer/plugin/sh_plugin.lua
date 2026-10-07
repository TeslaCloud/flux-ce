PLUGIN:set_global('Observer')

require_relative 'cl_hooks'
require_relative 'sv_hooks'

--- Registers the 'noclip' permission used by observer mode.
function Observer:RegisterPermissions()
  Bolt:register_permission('noclip', 'Noclip', 'Lets the player use observer mode / noclip.', 'permission.categories.general', 'moderator')
end
