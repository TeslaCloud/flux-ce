--- The `yell` command: says the text as a yell. A thin wrapper over the `text!!` markup of
-- regular chat.

CMD.name = 'Yell'
CMD.description = 'command.yell.description'
CMD.syntax = 'command.yell.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'y', 'shout', 's' }
CMD.arguments = 1
CMD.no_console = true

--- Says the text as a yell.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  Chatbox.player_say(actor, RPCommands:wrap_speech('yell', text))
end
