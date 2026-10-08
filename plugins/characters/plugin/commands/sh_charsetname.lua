--- Staff command that sets the name of a player's character.

CMD.name = 'CharSetName'
CMD.description = 'command.charsetname.description'
CMD.syntax = 'command.charsetname.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.alias = 'setname'

--- Sets the name of the first target's character and notifies staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param ... [Vararg words of the new name, joined with spaces]
function CMD:on_run(actor, targets, ...)
  local new_name = table.concat({ ... }, ' ')
  local target = targets[1]

  self:notify_staff('command.charsetname.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string({ target }),
    name = new_name
  })

  Characters.set_name(target, new_name)
  target:notify('notification.name_changed', { name = new_name })
end
