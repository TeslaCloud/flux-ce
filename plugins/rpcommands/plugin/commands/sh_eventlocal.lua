--- The `eventlocal` staff command: shows a line that describes an event to the players within
-- the talk radius of the caller, where the `event` command shows it to everyone.

CMD.name = 'EventLocal'
CMD.description = 'command.eventlocal.description'
CMD.syntax = 'command.eventlocal.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'localevent', 'el' }
CMD.arguments = 1
CMD.arg_types = { 'text' }
CMD.no_console = true

--- Shows an event message to the players within the talk radius of the caller and logs it.
-- @param actor [Player player running the command]
-- @param text [String the event, as it was typed]
function CMD:on_run(actor, text)
  Chatbox.add_text(nil, Color('orange'):lighten(30), text, {
    sender = actor,
    position = actor:EyePos(),
    radius = Config.get('rpcommands_talk_radius'),
    ic = true
  })

  Log:print(text, 'event')
end
