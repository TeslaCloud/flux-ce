PLUGIN:set_global('Observer')

require_relative 'cl_hooks'
require_relative 'sv_hooks'

function Bolt:RegisterPermissions()
  Bolt:register_permission('noclip', 'Noclip', 'Lets the player use observer mode / noclip.', 'permission.categories.general', 'moderator')
end
