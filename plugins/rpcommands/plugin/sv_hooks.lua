--- Server hooks of the RolePlay Commands plugin and the pipeline that turns a typed phrase into
-- a line of in character chat: `RPCommands:get_phrase_volume` (shared, in sh_plugin.lua) reads
-- how loud the phrase is, `RPCommands:get_phrase_table` splits it into speech and actions, and
-- `RPCommands:format_message` puts the chat line together. The file also sets the chat colors
-- and keeps the static texts.
--
-- The talk radius is the 'talk_radius' config, which is defined in config/config.yml and can
-- be edited in game. The chat colors are set here in code.

local config_get = Config.get

local ic_color = Color('khaki')
Config.set('chat_ic_color', ic_color)
Config.set('chat_whisper_color', ic_color:desaturate(40):darken(20))
Config.set('chat_yell_color', ic_color:saturate(30):lighten(15))
Config.set('chat_it_color', Color('lightblue'))
Config.set('chat_me_color', Color('lightgreen'))

--- Adds a static text, saves it and sends it to all players.
-- @param data [Table static text with pos, text, name, steamid and time fields]
function RPCommands.add_static_text(data)
  table.insert(RPCommands.texts, data)

  RPCommands:save()

  Cable.send(nil, 'fl_static_text_add', data)
end

--- Removes a static text, saves the change and removes it for all players.
-- @param id [Number index of the static text]
function RPCommands.remove_static_text(id)
  table.remove(RPCommands.texts, id)

  RPCommands:save()

  Cable.send(nil, 'fl_static_text_remove', id)
end

--- Limits voice chat to the talk radius.
-- @param listener [Player player that would hear the voice]
-- @param talker [Player player talking]
-- @return [Boolean false if the talker is out of range, nil otherwise]
function RPCommands:PlayerCanHearPlayersVoice(listener, talker)
  local radius = config_get('talk_radius')

  if listener:EyePos():DistToSqr(talker:EyePos()) > radius * radius then
    return false
  end
end

--- Replaces regular chat messages with formatted in character speech and logs them. A phrase
-- that the player may not say (see `RPCommands:can_say_ic`), or that has nothing in it but
-- markup, is replaced with a message that nobody hears and that
-- `RPCommands:ChatboxShouldSendMessage` cancels.
-- @param actor [Player player that sent the message]
-- @param text [String message text]
-- @param message_data [Table message data, replaced in place]
function RPCommands:ChatboxAdjustPlayerSay(actor, text, message_data)
  table.Empty(message_data)

  if !self:has_phrase_content(text) or !self:can_say_ic(actor, text) then
    table.insert(message_data, { radius = -1, refused = true })

    return
  end

  local msg_table = self:format_message(actor, text)

  table.Merge(message_data, msg_table)
  Log:print(Chatbox.message_to_string(msg_table, ' '), 'player_ic')
end

--- Cancels the message that stands in for a phrase a player was not allowed to say.
-- @param message_data [Table chat message data]
-- @param listeners [List<Player> players the message is meant for]
-- @return [Boolean false for a refused phrase, nil otherwise]
function RPCommands:ChatboxShouldSendMessage(message_data, listeners)
  if message_data.refused then
    return false
  end
end

--- Lets look-based messages be heard by players looking within the message radius of the sender.
-- @param listener [Player player that would hear the message]
-- @param message_data [Table chat message data]
-- @return [Boolean whether the listener hears a look-based message, nil for other messages]
function RPCommands:PlayerCanHear(listener, message_data)
  local radius = message_data.radius

  if message_data.hear_when_look and IsValid(message_data.sender) and isnumber(radius) then
    if radius < 0 then
      return false
    end

    local look_pos = listener:GetEyeTraceNoCursor().HitPos

    return message_data.sender:GetPos():DistToSqr(look_pos) <= radius * radius
  end
end

--- Prevents gagged players from using the OOC and LOOC chats.
-- @param actor [Player player trying to use OOC]
-- @return [Boolean false while the player is gagged, nil otherwise]
function RPCommands:PlayerCanUseOOC(actor)
  if self:get_ooc_mute_left(actor) > 0 then
    return false
  end
end

--- Loads the static texts with the rest of the server data.
function RPCommands:LoadData()
  self:load()
end

--- Saves the static texts with the rest of the server data.
function RPCommands:SaveData()
  self:save()
end

--- Saves the static texts to the plugin data.
function RPCommands:save()
  Data.save_plugin('rptexts', RPCommands.texts)
end

--- Loads the static texts from the plugin data.
function RPCommands:load()
  local texts = Data.load_plugin('rptexts', {})

  self.texts = texts
end

--- Sends all static texts to a player once they have loaded in.
-- @param actor [Player player that has loaded in]
function RPCommands:PlayerInitialized(actor)
  Cable.send(actor, 'fl_static_text_set', self.texts)
end

--- Splits a phrase into alternating speech and asterisk emote parts with quotes and colors.
-- @param text [String phrase]
-- @return [Table chat message parts]
function RPCommands:get_phrase_table(text)
  local msg_table = {}
  local is_emote = text:start_with('*')
  local text_parts = {}
  local pieces = text:split('*')
  local count = 0

  for i = 1, #pieces do
    local piece = pieces[i]

    if piece != '' and piece:match('%S') then
      count = count + 1
      text_parts[count] = piece
    end
  end

  local ic_color = config_get('chat_ic_color')
  local me_color = config_get('chat_me_color')
  local length = 0

  if !is_emote then
    length = 1
    msg_table[1] = '"'
  end

  for k = 1, count do
    if k != 1 then
      if !is_emote then
        length = length + 1
        msg_table[length] = ic_color
      end

      length = length + 1
      msg_table[length] = is_emote and '" ' or ' "'
    end

    local part = text_parts[k]:strip()

    if is_emote then
      length = length + 1
      msg_table[length] = me_color

      if part:is_upper() then
        part = part:utf8lower()
      end
    end

    if k == 1 or k == count then
      part = part:spelling(is_emote, k == 1 and count != 1)
    end

    length = length + 1
    msg_table[length] = part

    is_emote = !is_emote
  end

  if is_emote then
    msg_table[length + 1] = '"'
  end

  return msg_table
end

--- Formats an in character message, scaling its font size, verb and hearing radius by the phrase volume.
-- @param speaker [Player player speaking]
-- @param text [String phrase]
-- @return [Table chat message parts ending with the message data]
function RPCommands:format_message(speaker, text)
  local text, volume = self:get_phrase_volume(text)
  local is_emote = text:start_with('*')
  local color = config_get(is_emote and 'chat_me_color' or 'chat_ic_color')

  local msg_table = {
    color,
    config_get('default_font_size') + volume * 2,
    speaker, ' '
  }

  if !is_emote then
    msg_table[5] = volume == 0 and t'ui.chat.say' or (volume < 0 and t'ui.chat.whisper' or t'ui.chat.yell')
    msg_table[6] = ': '

    if volume == 3 then
      text = text:utf8upper()
    end
  else
    if volume > 0 then
      text = text:sub(1, -text:match('([!]+)$'):len() - 1)
    end
  end

  table.Add(msg_table, self:get_phrase_table(text))

  table.insert(msg_table, {
    sender = speaker,
    position = speaker:EyePos(),
    radius = config_get('talk_radius') * self:get_volume_range(volume),
    ic = true
  })

  return msg_table
end

--- Sends a colored chat message to a single player. Nothing is sent for a player who is not
-- valid, as the message would reach everyone instead.
-- @param receiver [Player player to send the message to]
-- @param notification_color [Color color of the message]
-- @param message [String message]
function RPCommands:NotifySelf(receiver, notification_color, message)
  if !IsValid(receiver) then return end

  Cable.send(receiver, 'fl_notify_self', receiver, notification_color, message)
end
