--- Server hooks of the Voice Lines plugin. In character speech is put together by the
-- `AdjustPlayerSay` handler of the RolePlay Commands plugin, which this plugin depends
-- on and therefore runs after: when the phrase says a line, the message is put together again
-- from the text of the line at the volume of the phrase, and the sound plays once the
-- chatbox has sent the message, to exactly the players who have received it. A phrase that is
-- a chain says its first line that way and starts the chain once the message has been sent.
-- Radio messages are handled through the hooks of the Radios plugin, when it is loaded. A
-- chain is canceled when its speaker leaves, dies or changes character.

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
-- once it has been sent. A phrase that is a chain is replaced with its first line, and the
-- mark carries the chain. Phrases that the RolePlay Commands plugin has refused are left alone.
-- The RolePlay Commands plugin has logged the phrase as it was typed, so the message that is
-- said instead is logged as well, as a 'player_voice_line' entry that names the line.
-- @param actor [Player the speaker]
-- @param text [String the phrase as it was typed, with its markup]
-- @param message [List arguments for Chatbox.add_text, replaced in place]
function VoiceLines:AdjustPlayerSay(actor, text, message)
  local options = get_options(message)

  if !options or options.refused or !options.ic then return end

  local phrase, volume = RPCommands:get_phrase_volume(text)
  local line, category, chain = self:find_spoken_line(actor, phrase)

  if !line then return end

  local phrase_text = self:wrap_text(self:get_text(line, self:get_gender(actor)), volume)

  table.Empty(message)
  table.Merge(message, RPCommands:format_message(actor, phrase_text))

  options = get_options(message)

  if options then
    options.voice_line = { category = category.id, line = line.id, volume = volume, chain = chain }
  end

  Log:print(Chatbox.message_to_string(message, ' ')..' ['..category.id..'/'..line.id..']', 'player_voice_line')
end

--- Plays the sound of a voice line to the players who have received the message that says it,
-- once the chain that the message starts, if any, has been started.
-- @param message_data [Map the message data, see Chatbox.add_text]
-- @param receivers [List<Player> the players the message has been sent to]
function VoiceLines:ChatboxMessageSent(message_data, receivers)
  local voice_line = message_data.voice_line

  if !istable(voice_line) then return end

  local category = self:find_category(voice_line.category)
  local line = category and category.lines[voice_line.line]

  if !line then return end

  if voice_line.chain then
    self:start_chain(message_data.sender, voice_line.chain, voice_line.volume)
  end

  self:play(message_data.sender, category, line, receivers, voice_line.volume)
end

--- Keeps the voice line of a message out of the copies that are sent to the clients.
-- @param _listener [Player the player the copy is for]
-- @param message_data [Map the copy of the message data]
function VoiceLines:AdjustMessageData(_listener, message_data)
  message_data.voice_line = nil
end

--- Replaces a radio message that says a voice line with the text of the line, and one that is
-- a chain with the text of its first line, marked with the chain. Lines whose text is an
-- action are not said over the radio.
-- @param speaker [Player the player talking on the radio]
-- @param info [Map the transmission, see the AdjustRadioInfo hook of the Radios plugin]
function VoiceLines:AdjustRadioInfo(speaker, info)
  if !isstring(info.text) then return end

  local line, category, chain = self:find_spoken_line(speaker, info.text, true)

  if !line then return end

  info.text = self:get_text(line, self:get_gender(speaker))
  info.voice_line = { category = category.id, line = line.id, chain = chain }
end

--- Plays the sound of a voice line said over the radio: from the speaker for the speaker and
-- the players who have overheard the message, at the volume of a whisper, and quieter for the
-- players who have received it over the radio. A message that starts a chain starts it first,
-- so that the next lines go over the radio as well.
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

  if voice_line.chain then
    self:start_chain(speaker, voice_line.chain, nil, true)
  end

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

--- Cancels the chain of a player who leaves.
-- @param actor [Player]
function VoiceLines:PlayerDisconnected(actor)
  self:cancel_chain(actor)
end

--- Cancels the chain of a player who dies.
-- @param victim [Player]
-- @param _inflictor [Entity]
-- @param _attacker [Entity]
function VoiceLines:PlayerDeath(victim, _inflictor, _attacker)
  self:cancel_chain(victim)
end

--- Cancels the chain of a player who selects another character.
-- @param owner [Player]
-- @param _new_char [Character the character that is about to become active]
-- @param _old_char [Character the character that is still active]
function VoiceLines:OnCharacterChange(owner, _new_char, _old_char)
  self:cancel_chain(owner)
end

--- Cancels the chain of a player who is left without a character.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function VoiceLines:ActiveCharacterCleared(owner, _character)
  self:cancel_chain(owner)
end
