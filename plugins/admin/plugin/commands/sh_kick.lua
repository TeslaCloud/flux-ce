--- The Kick command kicks the targeted players from the server, with an optional reason.

CMD.name = 'Kick'
CMD.description = 'command.kick.description'
CMD.syntax = 'command.kick.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'player', 'text' }
CMD.immunity = true
CMD.alias = 'plykick'

--- Kicks the targeted players with an optional reason, translated to the language of each
-- player, and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to kick]
-- @param reason=nil [String the kick reason, as it was typed]
function CMD:on_run(actor, targets, reason)
  if !reason or reason == '' then
    reason = 'ui.no_reason'
  end

  for _, client in ipairs(targets) do
    client:Kick(t(reason, nil, Flux.Lang:get_player_lang(client)))
  end

  self:notify_staff('command.kick.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    reason = reason
  })
end
