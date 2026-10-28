--- The Godmode command turns god mode on or off for players: `/godmode on <target>` and
-- `/godmode off <target>`. Both need the `godmode` permission.

CMD.name = 'Godmode'
CMD.description = 'command.godmode.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'god', 'plysetgodmode' }

local function set_godmode(cmd, actor, targets, enabled)
  for _, client in ipairs(targets) do
    if enabled then
      client:GodEnable()
    else
      client:GodDisable()
    end

    client:notify('notification.godmode.'..(enabled and 'enabled' or 'disabled'))
  end

  cmd:notify_staff('command.godmode.'..(enabled and 'on' or 'off')..'.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end

local on = CMD:subcommand('on')
on.description = 'command.godmode.on.description'
on.syntax = 'command.godmode.on.syntax'
on.arguments = 1
on.arg_types = { 'player' }
on.immunity = true

--- Turns god mode on for the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
function on:on_run(actor, targets)
  set_godmode(self, actor, targets, true)
end

local off = CMD:subcommand('off')
off.description = 'command.godmode.off.description'
off.syntax = 'command.godmode.off.syntax'
off.arguments = 1
off.arg_types = { 'player' }
off.immunity = true

--- Turns god mode off for the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
function off:on_run(actor, targets)
  set_godmode(self, actor, targets, false)
end
