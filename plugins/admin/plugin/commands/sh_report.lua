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
local report_interval = 5

--- Sends a report to every online player with the 'staff' permission and to the caller. A
-- caller who has sent a report within the last five seconds is told to wait instead.
-- @param actor [Player the caller]
-- @param text [String the report, as it was typed]
function CMD:on_run(actor, text)
  local cur_time = CurTime()

  if cur_time < (actor.fl_next_report or 0) then
    actor:notify('error.wait')

    return
  end

  actor.fl_next_report = cur_time + report_interval

  Bolt:send_staff_message(actor, text, '@report ', tag_color)
end
