--- The Freeze command freezes players in place and unfreezes them: `/freeze on <target>` and
-- `/freeze off <target>`. Both need the `freeze` permission.

CMD.name = 'Freeze'
CMD.description = 'command.freeze.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'plyfreeze' }

local on = CMD:subcommand('on')
on.description = 'command.freeze.on.description'
on.syntax = 'command.freeze.on.syntax'
on.arguments = 1
on.arg_types = { 'player' }
on.immunity = true

--- Freezes the targeted players in place and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to freeze]
function on:on_run(actor, targets)
  for _, v in ipairs(targets) do
    v:Freeze(true)
    v:notify('notification.freeze', {
      player = actor
    })
  end

  self:notify_staff('command.freeze.on.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end

local off = CMD:subcommand('off')
off.description = 'command.freeze.off.description'
off.syntax = 'command.freeze.off.syntax'
off.arguments = 1
off.arg_types = { 'player' }
off.immunity = true

--- Unfreezes the targeted players and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to unfreeze]
function off:on_run(actor, targets)
  for _, v in ipairs(targets) do
    v:Freeze(false)
    v:notify('notification.unfreeze', {
      player = actor
    })
  end

  self:notify_staff('command.freeze.off.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
