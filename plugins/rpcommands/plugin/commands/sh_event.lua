--- The `event` staff command: shows a line that describes an event to every player.

CMD.name = 'Event'
CMD.description = 'command.event.description'
CMD.syntax = 'command.event.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1
CMD.arg_types = { 'text' }

--- Broadcasts an event message to all players and logs it.
-- @param _actor [Player player running the command]
-- @param text [String the event, as it was typed]
function CMD:on_run(_actor, text)
  Chatbox.add_text(nil, Color('orange'):lighten(30), text)

  Log:print(text, 'event')
end
