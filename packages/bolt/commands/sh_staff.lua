--- The Staff command sends a chat message that only the online players with the `staff`
-- permission receive.

CMD.name = 'Staff'
CMD.description = 'command.staff.description'
CMD.syntax = 'command.staff.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'text' }
CMD.no_console = true

local tag_color = Color(234, 255, 208)

--- Sends a chat message to every online player with the 'staff' permission.
-- @param actor [Player the caller]
-- @param text [String the message, as it was typed]
function CMD:on_run(actor, text)
  Bolt:send_staff_message(actor, text, '@staff ', tag_color)
end
