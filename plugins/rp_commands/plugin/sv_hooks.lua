--- Server-side hooks of the RolePlay Commands plugin: the hearing range of voice and chat,
-- in character chat lines, the OOC mute of the out of character chats and of private messages,
-- and loading, saving and sending the static texts.
--
-- The talk radius is the 'rp_commands_talk_radius' config and the chat colors are the 'rp_commands_*_color'
-- configs, all of them defined in config/config.yml.

local talk_radius = Config.get('rp_commands_talk_radius', 350)
local talk_radius_sqr = talk_radius * talk_radius

--- Keeps the talk radius that the hooks of this file read, and its square, in step with the
-- 'rp_commands_talk_radius' config.
-- @param key [String config key]
-- @param _old_value [Any]
-- @param new_value [Any]
function RPCommands:ConfigChanged(key, _old_value, new_value)
  if key == 'rp_commands_talk_radius' then
    talk_radius = tonumber(new_value) or 350
    talk_radius_sqr = talk_radius * talk_radius
  end
end

--- Limits voice chat to the talk radius.
-- @param listener [Player player that would hear the voice]
-- @param talker [Player player talking]
-- @return [Boolean false if the talker is out of range, nil otherwise]
function RPCommands:PlayerCanHearPlayersVoice(listener, talker)
  if listener:EyePos():DistToSqr(talker:EyePos()) > talk_radius_sqr then
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
-- @return [Boolean true if the listener looks within the radius of a look-based message, nil
--   otherwise]
function RPCommands:PlayerCanHearChat(listener, message_data)
  local radius = message_data.radius

  if message_data.hear_when_look and IsValid(message_data.sender) and isnumber(radius) then
    if radius < 0 then return end

    local look_pos = listener:GetEyeTraceNoCursor().HitPos

    return message_data.sender:GetPos():DistToSqr(look_pos) <= radius * radius or nil
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

--- Holds private messages to the rules of the out of character chats: a player who may not
-- use them right now, such as one with an OOC mute, may not send a private message either
-- (see `RPCommands:can_use_ooc`, with the 'message' kind).
-- @param actor [Player the sender]
-- @param _target [Player the recipient]
-- @param text [String the message]
-- @return [Boolean false if the player may not use the out of character chats, nil otherwise]
function RPCommands:PlayerCanSendPrivateMessage(actor, _target, text)
  if !self:can_use_ooc(actor, 'message', text) then
    return false
  end
end

--- Gives the text of a whisper that is being typed the range the whisper will be heard
-- within, so that the players beyond it see the outline of the text in the typing bubble and
-- not the text (see `RPCommands:get_typing_kind`).
-- @param _actor [Player the typing player]
-- @param text [String the text being typed]
-- @param _kind_id [String ID of the kind of speech the client has reported]
-- @return [Number the hearing range of a phrase below the volume of regular speech, nil for
--   anything else]
function RPCommands:GetTypingTextRange(_actor, text, _kind_id)
  local id, volume = self:get_typing_kind(text)

  if id and volume < 0 then
    return talk_radius * self:get_volume_range(volume)
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
  self:send_static_texts(actor)
end

--- Sends all static texts to a player again once their role has changed, so that the
-- client's copy holds the authors exactly when the role they have been given may see them. A
-- player who has not loaded in yet receives the texts from `RPCommands:PlayerInitialized`.
-- @param target [Player the player whose role has changed]
-- @param _group [Role the role they have been given, nil when no registered role stands for its
--   usergroup]
-- @param _old_group [Role the previous role, nil when no registered role stands for its usergroup]
function RPCommands:PlayerUserGroupChanged(target, _group, _old_group)
  if !IsValid(target) or !target:has_initialized() then return end

  self:send_static_texts(target)
end
