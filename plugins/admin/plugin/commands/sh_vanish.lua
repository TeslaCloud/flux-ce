--- The Vanish command hides players from everyone who lacks the `moderate` permission and shows
-- them again: `/vanish on <target>` and `/vanish off <target>`. Both need the `vanish`
-- permission.

CMD.name = 'Vanish'
CMD.description = 'command.vanish.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'v' }

--- Hides or shows the targeted players and notifies them and staff.
-- @param cmd [Command the subcommand that runs]
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
-- @param should_vanish [Boolean true to hide them, false to show them again]
local function set_vanished(cmd, actor, targets, should_vanish)
  for _, client in ipairs(targets) do
    client:set_vanished(should_vanish)
    client:notify('notification.vanish.'..(should_vanish and 'enabled' or 'disabled'))
  end

  cmd:notify_staff('command.vanish.'..(should_vanish and 'on' or 'off')..'.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end

local on = CMD:subcommand('on')
on.description = 'command.vanish.on.description'
on.syntax = 'command.vanish.on.syntax'
on.arguments = 1
on.arg_types = { 'player' }
on.immunity = true

--- Hides the targeted players from everyone without the 'moderate' permission.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to hide]
function on:on_run(actor, targets)
  set_vanished(self, actor, targets, true)
end

local off = CMD:subcommand('off')
off.description = 'command.vanish.off.description'
off.syntax = 'command.vanish.off.syntax'
off.arguments = 1
off.arg_types = { 'player' }
off.immunity = true

--- Shows the targeted players to everyone again.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to show]
function off:on_run(actor, targets)
  set_vanished(self, actor, targets, false)
end
