--- Observer turns noclip into an observer mode for staff: a noclipping player is invisible,
-- not solid, invulnerable and hidden from everyone without the 'moderate' permission.
-- Entering it requires the 'noclip' permission. A player who leaves observer mode is put back
-- where they entered it if the `observer_reset` config is on; plugins can decide that per
-- player through the `ShouldObserverReset` hook.

PLUGIN:set_global('Observer')

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
