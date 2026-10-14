--- The `whisper` command: says the text as a whisper. A thin wrapper over the `(text)` markup
-- of regular chat.

CMD.name = 'Whisper'
CMD.description = 'command.whisper.description'
CMD.syntax = 'command.whisper.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.alias = 'w'
CMD.arguments = 1
CMD.no_console = true

--- Says the text as a whisper.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  Chatbox.player_say(actor, RPCommands:wrap_speech('whisper', text))
end
