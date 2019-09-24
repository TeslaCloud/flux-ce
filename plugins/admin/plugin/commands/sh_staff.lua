CMD.name = 'Staff'
CMD.description = 'command.staff.description'
CMD.syntax = 'command.staff.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1

function CMD:on_run(player, ...)
  local text = table.concat({ ... }, ' ')

  local msg_table = {
    Color(234,255,208),
    '@staff ',
    hook.run('ChatboxGetPlayerColor', player, text, team_chat) or _team.GetColor(player:Team()),
    get_player_name(player),
    hook.run('ChatboxGetMessageColor', player, text, team_chat) or Color(255, 255, 255),
      ': ',
      text:chomp(' '),
      { sender = player }
  }

  Chatbox.add_text(Bolt:get_staff(), unpack(msg_table))
end
