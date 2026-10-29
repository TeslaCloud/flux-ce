--- Server hooks of the Voice Lines plugin. In character speech is put together by the
-- `AdjustPlayerSay` handler of the RolePlay Commands plugin, which this plugin depends
-- on and therefore runs after: when the phrase says a line, the message is put together again
-- from the text of the line at the volume of the phrase, and the sound plays once the
-- chatbox has sent the message, to exactly the players who have received it. Radio messages
-- are handled through the hooks of the Radios plugin, when it is loaded.

--- Returns the options table of a message for `Chatbox.add_text`: its last table that is
-- not a piece of the message.
-- @param message [List arguments for Chatbox.add_text]
-- @return [Map the options, nil if the message has none]
local function get_options(message)
  for i = #message, 1, -1 do
    local piece = message[i]

    if istable(piece) and !piece.is_data and !IsColor(piece) then
      return piece
    end
  end
end

--- Replaces a phrase of in character speech that says a voice line with the text of the line,
-- said at the volume of the phrase, and marks the message so that the sound of the line plays
-- once it has been sent. Phrases that the RolePlay Commands plugin has refused are left alone.
-- The RolePlay Commands plugin has logged the phrase as it was typed, so the message that is
-- said instead is logged as well, as a 'player_voice_line' entry that names the line.
-- @param actor [Player the speaker]
-- @param text [String the phrase as it was typed, with its markup]
-- @param message [List arguments for Chatbox.add_text, replaced in place]
function VoiceLines:AdjustPlayerSay(actor, text, message)
  local options = get_options(message)

  if !options or options.refused or !options.ic then return end

  local phrase, volume = RPCommands:get_phrase_volume(text)
  local line, category = self:find_spoken_line(actor, phrase)

  if !line then return end

  local phrase_text = self:wrap_text(self:get_text(line, self:get_gender(actor)), volume)

  table.Empty(message)
  table.Merge(message, RPCommands:format_message(actor, phrase_text))

  options = get_options(message)

  if options then
    options.voice_line = { category = category.id, line = line.id, volume = volume }
  end

  Log:print(Chatbox.message_to_string(message, ' ')..' ['..category.id..'/'..line.id..']', 'player_voice_line')
end

--- Plays the sound of a voice line to the players who have received the message that says it.
-- @param message_data [Map the message data, see Chatbox.add_text]
-- @param receivers [List<Player> the players the message has been sent to]
function VoiceLines:ChatboxMessageSent(message_data, receivers)
  local voice_line = message_data.voice_line

  if !istable(voice_line) then return end

  local category = self:find_category(voice_line.category)
  local line = category and category.lines[voice_line.line]

  if line then
    self:play(message_data.sender, category, line, receivers, voice_line.volume)
  end
end

--- Keeps the voice line of a message out of the copies that are sent to the clients.
-- @param _listener [Player the player the copy is for]
-- @param message_data [Map the copy of the message data]
function VoiceLines:AdjustMessageData(_listener, message_data)
  message_data.voice_line = nil
end

--- Replaces a radio message that says a voice line with the text of the line. Lines whose text
-- is an action are not said over the radio.
-- @param speaker [Player the player talking on the radio]
-- @param info [Map the transmission, see the AdjustRadioInfo hook of the Radios plugin]
function VoiceLines:AdjustRadioInfo(speaker, info)
  if !isstring(info.text) then return end

  local line, category = self:match(speaker, info.text, true)

  if !line then return end

  info.text = self:get_text(line, self:get_gender(speaker))
  info.voice_line = { category = category.id, line = line.id }
end

--- Plays the sound of a voice line said over the radio: from the speaker for the speaker and
-- the players who have overheard the message, at the volume of a whisper, and quieter for the
-- players who have received it over the radio.
-- @param speaker [Player the player who has talked on the radio]
-- @param info [Map the transmission as it was sent]
-- @param listeners [List<Player> the players who have received the message over the radio]
-- @param eavesdroppers [List<Player> the players who have overheard it]
function VoiceLines:PlayerUsedRadio(speaker, info, listeners, eavesdroppers)
  local voice_line = info.voice_line

  if !istable(voice_line) then return end

  local category = self:find_category(voice_line.category)
  local line = category and category.lines[voice_line.line]

  if !line then return end

  local nearby = { speaker }
  local remote = {}

  for _k, listener in ipairs(eavesdroppers) do
    nearby[#nearby + 1] = listener
  end

  for _k, listener in ipairs(listeners) do
    if listener != speaker then
      remote[#remote + 1] = listener
    end
  end

  self:play(speaker, category, line, nearby, -1, remote)
end
