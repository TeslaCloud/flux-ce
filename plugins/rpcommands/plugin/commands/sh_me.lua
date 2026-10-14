--- The `me` command: says the text as an action. A thin wrapper over the `*text*` markup of
-- regular chat.

CMD.name = 'Me'
CMD.description = 'command.me.description'
CMD.syntax = 'command.me.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'e', 'action', 'perform' }
CMD.arguments = 1
CMD.no_console = true

--- Says the text as an emote.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  Chatbox.player_say(actor, RPCommands:wrap_speech('me', text))
end
