--- Server-side hooks of the RolePlay Commands plugin: the hearing range of voice and chat,
-- in character chat lines, the OOC mute, and loading, saving and sending the static texts.
--
-- The talk radius is the 'rp_commands_talk_radius' config and the chat colors are the 'rp_commands_*_color'
-- configs, all of them defined in config/config.yml.

local config_get = Config.get

--- Limits voice chat to the talk radius.
-- @param listener [Player player that would hear the voice]
-- @param talker [Player player talking]
-- @return [Boolean false if the talker is out of range, nil otherwise]
function RPCommands:PlayerCanHearPlayersVoice(listener, talker)
  local radius = config_get('rp_commands_talk_radius')

  if listener:EyePos():DistToSqr(talker:EyePos()) > radius * radius then
    return false
  end
end

--- Replaces regular chat messages with formatted in character speech and logs them. A phrase
-- that the player may not say (see `RPCommands:can_say_ic`), or that has nothing in it but
-- markup, is replaced with a message that nobody hears and that
-- `RPCommands:ShouldSendChatMessage` cancels.
-- @param actor [Player player that sent the message]
-- @param text [String message text]
-- @param message_data [Table message data, replaced in place]
function RPCommands:AdjustPlayerSay(actor, text, message_data)
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
-- @param _listeners [List<Player> players the message is meant for]
-- @return [Boolean false for a refused phrase, nil otherwise]
function RPCommands:ShouldSendChatMessage(message_data, _listeners)
  if message_data.refused then
    return false
  end
end

--- Lets look-based messages be heard by players looking within the message radius of the sender.
-- @param listener [Player player that would hear the message]
-- @param message_data [Table chat message data]
-- @return [Boolean whether the listener hears a look-based message, nil for other messages]
function RPCommands:PlayerCanHearChat(listener, message_data)
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

--- Sends all static texts to a player once they have loaded in.
-- @param actor [Player player that has loaded in]
function RPCommands:PlayerInitialized(actor)
  Cable.send(actor, 'fl_static_text_set', self.texts)
end
