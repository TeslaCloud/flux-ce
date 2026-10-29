--- The Report command: `/report <text>` sends a chat message to the reporting player and to
-- every online player with the `staff` permission.

CMD.name = 'Report'
CMD.description = 'command.report.description'
CMD.syntax = 'command.report.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 1
CMD.arg_types = { 'text' }
CMD.aliases = { 'help' }
CMD.no_console = true

local tag_color = Color(184, 59, 94)

--- Sends a report to every online player with the 'staff' permission and to the caller.
-- @param actor [Player the caller]
-- @param text [String the report, as it was typed]
function CMD:on_run(actor, text)
  Bolt:send_staff_message(actor, text, '@report ', tag_color)
end
