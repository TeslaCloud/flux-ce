CMD.name = 'Staff'
CMD.description = 'command.staff.description'
CMD.syntax = 'command.staff.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1

--- Sends a chat message to every online player with the 'staff' permission.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param ... [Vararg words of the message]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  local msg_table = {
    Color(234, 255, 208),
    '@staff ',
    hook.Run('ChatboxGetPlayerColor', actor, text, team_chat) or team.GetColor(actor:Team()),
    get_player_name(actor),
    hook.Run('ChatboxGetMessageColor', actor, text, team_chat) or Color(255, 255, 255),
    ': ',
    text:chomp(' '),
    { sender = actor }
  }

  Chatbox.add_text(Bolt:get_staff(), unpack(msg_table))
end
