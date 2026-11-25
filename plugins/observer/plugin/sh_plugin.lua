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
-- weapons. These players do not see the hidden player on the scoreboard or among the
-- suggestions for the player arguments of commands, and do not hear them over voice chat.
-- Hidden players cannot pick up weapons that lie in the world or carry
-- objects in their hands.
-- Observer mode is the `observer` networked variable of the player, which only the player
-- receives; the public `hidden` networked variable tells every client who is hidden.
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

--- Completes arguments of the 'player' type, wrapping the completer that was registered for
-- that type when `Observer:PluginsLoaded` ran. A player without the 'moderate' permission is
-- not offered the character names, Steam names and SteamIDs of hidden players, unless a player
-- they can see has the same one. The server console and players with 'moderate' get every
-- suggestion.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments typed before it]
-- @param cmd [Command the command or subcommand the argument belongs to]
-- @return [List<String> the names to suggest]
function Observer.complete_player(actor, partial, args, cmd)
  local base = Observer.base_player_completer
  local values = isfunction(base) and base(actor, partial, args, cmd) or {}

  if !IsValid(actor) or actor:can('moderate') then
    return values
  end

  local hidden, shown = {}, {}

  for _, client in player.Iterator() do
    local names = (client != actor and client:get_nv('hidden')) ? hidden : shown

    names[client:name(true)] = true
    names[client:steam_name()] = true
    names[client:SteamID()] = true
  end

  local allowed = {}

  for _, value in ipairs(values) do
    if shown[value] or !hidden[value] then
      allowed[#allowed + 1] = value
    end
  end

  return allowed
end

--- Wraps the 'player' completer with `Observer.complete_player` once every plugin has been
-- included, so that the wrapper comes after those that other plugins put in place while they
-- loaded, whatever their order. When the completer is still the wrapper put in place last
-- time, as after a code refresh that has not registered the completer again, that wrapper is
-- replaced and its base kept, so that wrappers never stack.
function Observer:PluginsLoaded()
  local current = Flux.Command:get_completer('player')

  if current != Observer.player_completer then
    Observer.base_player_completer = current
  end

  Observer.player_completer = Observer.complete_player

  Flux.Command:add_completer('player', Observer.complete_player)
end
