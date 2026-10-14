--- The Vanish command hides the targeted players from everyone who lacks the `moderate`
-- permission when given a true value, and toggles their visibility otherwise. Allowed for
-- assistants by default.

CMD.name = 'Vanish'
CMD.description = 'command.vanish.description'
CMD.syntax = 'command.vanish.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'v'

--- Hides the targeted players from everyone without the 'moderate' permission, or toggles
-- their visibility when no truthy value is given, and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
-- @param should_vanish=nil [String value read with tobool; truthy vanishes the targets,
--   anything else (or nothing) toggles them]
function CMD:on_run(actor, targets, should_vanish)
  for k, v in ipairs(targets) do
    should_vanish = should_vanish != nil and tobool(should_vanish) or !v.is_vanished

    v:set_vanished(should_vanish)
    v:notify('notification.vanish.'..(should_vanish and 'enabled' or 'disabled'))
  end

  self:notify_staff('command.vanish.'..(should_vanish and 'enabled' or 'disabled'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
