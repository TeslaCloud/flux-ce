--- A skeleton to start new plugins from.
-- It does nothing by itself. Copy the folder, fill in `plugin.yml` and change the name passed
-- to `PLUGIN:set_global`: that global table is what the plugin's hooks and functions are
-- defined on. Shared code goes into this file, client and server hooks go into `cl_hooks.lua`
-- and `sv_hooks.lua`, the handlers of network messages into `cl_nethooks.lua` and
-- `sv_nethooks.lua`, libraries into `lib/` and phrases into `languages/`. The root of the
-- plugin holds no other files than `cl_plugin.lua`, `sh_plugin.lua`, `sv_plugin.lua` and the
-- hooks and nethooks files of each realm. The `plugin.yml` of the skeleton limits it to the
-- development environment.
-- @environment [development]
-- @module [DemoPlugin]

PLUGIN:set_global('DemoPlugin')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
