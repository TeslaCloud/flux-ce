--- The Fullbright command turns fullbright rendering, which ignores the map's lighting, on
-- or off for the targeted players. Allowed for moderators by default.

CMD.name = 'Fullbright'
CMD.description = 'command.fullbright.description'
CMD.syntax = 'command.fullbright.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.alias = 'fb'

--- Turns fullbright rendering on or off for the targeted players and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
-- @param should_fullbright [String value read with tobool, e.g. '1' or '0']
function CMD:on_run(actor, targets, should_fullbright)
  should_fullbright = tobool(should_fullbright)

  for k, v in ipairs(targets) do
    v:set_nv('should_fullbright', should_fullbright)
    v:notify('notification.fullbright.'..(should_fullbright and 'enabled' or 'disabled'))
  end

  self:notify_staff('command.fullbright.'..(should_fullbright and 'enabled' or 'disabled'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
