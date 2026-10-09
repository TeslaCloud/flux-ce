--- The Announce command shows a notice with the given text to every player on the server.
-- Allowed for assistants by default.

CMD.name = 'Announce'
CMD.description = 'command.announce.description'
CMD.syntax = 'command.announce.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1

local announcement_color = Color(255, 210, 100)

--- Shows the text to every player as a notification, labelled as an announcement. Percent
-- signs in the text are doubled before it is sent: the text is a phrase argument, and `t`
-- would read a single one as the start of a capture reference.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param ... [Vararg words of the announcement]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' '):chomp(' ')

  if text == '' then
    Flux.Player:notify(actor, 'error.command.syntax', {
      command = self.name,
      syntax = self.syntax
    })

    return
  end

  self:notify(nil, 'notification.announcement', { text = text }, announcement_color)
end
