--- The `event` staff command: shows a line that describes an event to every player.

CMD.name = 'Event'
CMD.description = 'command.event.description'
CMD.syntax = 'command.event.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1

--- Broadcasts an event message to all players and logs it.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  Chatbox.add_text(nil, Color('orange'):lighten(30), text)

  Log:print(text, 'event')
end
