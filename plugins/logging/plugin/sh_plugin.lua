--- Improved Console Logs prints the damage that players take to the server console and sends
-- it to the consoles of the players with the 'staff' permission.

PLUGIN:set_global('Logging')

require_relative 'cl_nethooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
