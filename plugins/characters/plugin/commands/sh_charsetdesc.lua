--- Staff command that sets the physical description of a player's character.

CMD.name = 'CharSetDesc'
CMD.description = 'command.charsetdesc.description'
CMD.syntax = 'command.charsetdesc.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'setdesc', 'setdescription', 'physdesc' }

--- Sets the physical description of the first target's character and notifies staff.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param ... [Vararg words of the new description, joined with spaces]
function CMD:on_run(actor, targets, ...)
  local new_desc = table.concat({ ... }, ' ')
  local target = targets[1]

  Characters.set_desc(target, new_desc)
  target:notify('notification.desc_changed', { desc = new_desc })

  self:notify_staff('command.charsetdesc.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string({ target }),
    desc = new_desc
  })
end
