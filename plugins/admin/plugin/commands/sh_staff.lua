--- The Staff command sends a chat message that only the online players with the `staff`
-- permission receive. Allowed for assistants by default.

CMD.name = 'Staff'
CMD.description = 'command.staff.description'
CMD.syntax = 'command.staff.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1

--- Sends a chat message to every online player with the 'staff' permission.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param ... [Vararg words of the message]
function CMD:on_run(actor, ...)
  local text = table.concat({ ... }, ' ')

  local msg_table = {
    Color(234, 255, 208),
    '@staff ',
    --- Run by the Staff command to get the color of the sender's name, the same hook the
    -- chatbox runs for a regular chat message.
    -- @param speaker [Player Player who sent the staff message]
    -- @param text [String The message]
    -- @return [Color Color of the name; the color of the sender's team when nothing is
    --   returned]
    hook.Run('ChatboxGetPlayerColor', actor, text) or team.GetColor(actor:Team()),
    get_player_name(actor),
    --- Run by the Staff command to get the color of the message text, the same hook the
    -- chatbox runs for a regular chat message.
    -- @param speaker [Player Player who sent the staff message]
    -- @param text [String The message]
    -- @return [Color Color of the text; white when nothing is returned]
    hook.Run('ChatboxGetMessageColor', actor, text) or Color(255, 255, 255),
    ': ',
    text:chomp(' '),
    { sender = actor }
  }

  Chatbox.add_text(Bolt:get_staff(), unpack(msg_table))
end
