--- The Fullbright command turns fullbright rendering, which ignores the map's lighting, on or
-- off for players: `/fullbright on <target>` and `/fullbright off <target>`. Both need the
-- `fullbright` permission.

CMD.name = 'Fullbright'
CMD.description = 'command.fullbright.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'fb' }

local function set_fullbright(cmd, actor, targets, enabled)
  for _, client in ipairs(targets) do
    client:set_nv('should_fullbright', enabled)
    client:notify('notification.fullbright.'..(enabled ? 'enabled' : 'disabled'))
  end

  cmd:notify_staff('command.fullbright.'..(enabled ? 'on' : 'off')..'.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end

local on = CMD:subcommand('on')
on.description = 'command.fullbright.on.description'
on.syntax = 'command.fullbright.on.syntax'
on.arguments = 1
on.arg_types = { 'player' }
on.immunity = true

--- Turns fullbright rendering on for the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
function on:on_run(actor, targets)
  set_fullbright(self, actor, targets, true)
end

local off = CMD:subcommand('off')
off.description = 'command.fullbright.off.description'
off.syntax = 'command.fullbright.off.syntax'
off.arguments = 1
off.arg_types = { 'player' }
off.immunity = true

--- Turns fullbright rendering off for the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
function off:on_run(actor, targets)
  set_fullbright(self, actor, targets, false)
end
