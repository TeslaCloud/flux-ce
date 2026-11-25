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

--- Sends a private message to a player and echoes it back to the sender, the sender seeing
-- whom it went to and the target whom it came from. A caller who targets themselves is told
-- that they cannot, and the PlayerCanSendPrivateMessage hook can refuse the message.
-- @param actor [Player the caller]
-- @param targets [List<Player> recipients, only the first one is used]
-- @param text [String the message, as it was typed]
function CMD:on_run(actor, targets, text)
  local target = targets[1]

  if target == actor then
    actor:notify('error.message.self')

    return
  end

  text = Chatbox.check_command_text(actor, text)

  if !text then return end

  text = text:chomp(' ')

  --- Decides whether a player may send a private message with the `message` command. Called
  -- on the server before the message is sent.
  -- @param actor [Player the sender]
  -- @param target [Player the recipient]
  -- @param text [String the message]
  -- @return [Boolean return false to refuse the message; the handler should tell the sender why]
  if hook.Run('PlayerCanSendPrivateMessage', actor, target, text) == false then return end

  local pieces = {
    message_color,
    { icon = 'fa-paper-plane', size = 16, margin = 12, is_data = true },
    t('ui.chat.message_to', { name = get_player_name(target) }, Flux.Lang:get_player_lang(actor)),
    ': ',
    hook.Run('GetChatMessageColor', actor, text) or Color(255, 255, 255),
    text,
    { sender = actor }
  }

  Chatbox.add_text(actor, unpack(pieces))

  pieces[3] = t('ui.chat.message_from', { name = get_player_name(actor) }, Flux.Lang:get_player_lang(target))

  Chatbox.add_text(target, unpack(pieces))
end
