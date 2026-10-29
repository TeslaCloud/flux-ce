--- The Message command: `/message <target> <text>` sends a private message to a player, the
-- one whose name is typed exactly or the first one a target selector finds.

CMD.name = 'Message'
CMD.description = 'command.message.description'
CMD.syntax = 'command.message.syntax'
CMD.category = 'permission.categories.general'
CMD.arguments = 2
CMD.arg_types = { 'player', 'text' }
CMD.aliases = { 'pm', 'msg' }
CMD.permission = 'user'
CMD.no_console = true

local message_color = Color(0, 173, 181)

--- Sends a private message to a player and echoes it back to the sender, each of them seeing
-- the name of the other. A caller who targets themselves is told that they cannot.
-- @param actor [Player the caller]
-- @param targets [List<Player> recipients, only the first one is used]
-- @param text [String the message, as it was typed]
function CMD:on_run(actor, targets, text)
  local target = targets[1]

  if target == actor then
    actor:notify('error.message.self')

    return
  end

  local pieces = {
    message_color,
    { icon = 'fa-paper-plane', size = 16, margin = 12, is_data = true },
    get_player_name(target),
    ': ',
    hook.Run('ChatboxGetMessageColor', actor, text) or Color(255, 255, 255),
    text:chomp(' '),
    { sender = actor }
  }

  Chatbox.add_text(actor, unpack(pieces))

  pieces[3] = get_player_name(actor)

  Chatbox.add_text(target, unpack(pieces))
end
