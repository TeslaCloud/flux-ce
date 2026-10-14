--- The `it` command: describes something that happens around the character, as a line that
-- is not said by anyone. It takes the same volume markup as speech.

CMD.name = 'It'
CMD.description = 'command.it.description'
CMD.syntax = 'command.it.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.alias = 'do'
CMD.arguments = 1
CMD.no_console = true

--- Describes something in the environment to players looking near the speaker, with a volume-based radius.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local text, volume = RPCommands:get_phrase_volume(table.concat({ ... }, ' '):spelling())
  local msg_table = {
    Config.get('chat_it_color'):saturate(volume * 10):lighten(volume * 10),
    Config.get('default_font_size'),
    '(', actor, ') ', text
  }

  table.insert(msg_table, {
    sender = actor,
    position = actor:EyePos(),
    radius = Config.get('talk_radius') * RPCommands:get_volume_range(volume),
    hear_when_look = true,
    ic = true
  })

  Chatbox.add_text(nil, unpack(msg_table))
  Log:print(Chatbox.message_to_string(msg_table, ' '), 'player_ic')
end
