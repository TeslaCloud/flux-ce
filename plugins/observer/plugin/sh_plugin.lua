--- Observer keeps staff out of sight of the other players. It has three parts:
--
-- - Observer mode replaces noclip for staff: a noclipping player is invisible, not solid,
--   invulnerable and hidden from everyone without the 'moderate' permission. Entering it
--   requires the 'noclip' permission. A player who leaves observer mode is put back where
--   they entered it if the `observer_reset` config is on; plugins can decide that per player
--   through the `ShouldObserverReset` hook.
-- - Vanish hides a player who walks among the others in the same way, without noclip:
--   `/vanish on|off <target>`, which takes the `vanish` permission, or `Player:set_vanished`.
--   A vanished player sees an indicator in the corner of the screen.
-- - The admin ESP shows players with the 'admin_esp' permission the name, Steam name, an
--   outline box and health and armor bars of every other player through walls while they
--   noclip. Its colors are the `esp_red`, `esp_blue` and `esp_grey` colors of the theme.
--
-- A hidden player, vanished or observing (`Player:is_hidden`), is not networked to players
-- without the 'moderate' permission, and neither is anything attached to them, such as their
-- weapons. Hidden players cannot pick up weapons that lie in the world or carry objects in
-- their hands. Observer mode is the `observer` networked variable of the player.
-- @module [Observer]

PLUGIN:set_global('Observer')

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Registers the 'admin_esp' permission.
function Observer:RegisterPermissions()
  Bolt:register_permission('admin_esp', nil, nil, 'permission.categories.administration')
end
