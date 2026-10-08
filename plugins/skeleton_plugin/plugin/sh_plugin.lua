--- A skeleton to start new plugins from.
-- It does nothing by itself. Copy the folder, fill in `plugin.yml` and change the name passed
-- to `PLUGIN:set_global`: that global table is what the plugin's hooks and functions are
-- defined on. Shared code goes into this file, client and server hooks go into `cl_hooks.lua`
-- and `sv_hooks.lua`, and phrases into `languages/`. The `plugin.yml` of the skeleton limits
-- it to the development environment.
-- @environment [development]
-- @module [flDemoPlugin]

PLUGIN:set_global('flDemoPlugin')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
