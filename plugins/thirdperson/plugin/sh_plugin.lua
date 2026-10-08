--- Third Person lets players switch between the first person view and a camera behind their
-- character.
-- The view is toggled with the `fl_third_person` console command, which the plugin binds to
-- the P key by default. The state is networked as the `fl_third_person` variable of the
-- player.
-- @module [ThirdPerson]

PLUGIN:set_global('ThirdPerson')

require_relative 'sv_plugin'
require_relative 'cl_plugin'
