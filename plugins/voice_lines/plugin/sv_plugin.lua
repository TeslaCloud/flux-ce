--- Server side of the Voice Lines plugin: turns the text of a line into a phrase of in character
-- speech, plays the sound of a line to the players who hear it, holds players to the
-- 'voice_lines_interval' config and says a line that a player has picked on the Voice Lines
-- page or that a chain says next.

local config_get = Config.get

--- The line that `VoiceLines:speak_line` is making a player say: actor, category and line. It is
-- only set while `Chatbox.submit` or `Radios.say_radio` runs, which turns the text into a
-- message right away.
local forced = nil

--- Writes the text of a line as a phrase of the volume it is said at, in the markup of the
-- RolePlay Commands plugin: parentheses for a whisper, exclamation marks for a yell.
-- ```
-- VoiceLines:wrap_text('Figures.', -1) -- '(Figures.)'
-- VoiceLines:wrap_text('Figures.', 1) -- 'Figures!!'
-- ```
-- @param text [String the text of the line]
-- @param volume=0 [Number volume from -3 to 3, as `RPCommands:get_phrase_volume` returns it]
-- @return [String the phrase]
function VoiceLines:wrap_text(text, volume)
  volume = tonumber(volume) or 0

  if volume < 0 then
    return string.rep('(', -volume)..text..string.rep(')', -volume)
  elseif volume > 0 then
    if !self:is_action(text) then
      text = text:gsub('[%.!%?]+$', '')
    end

    return text..string.rep('!', volume + 1)
  end

  return text
end

--- Returns how far the sound of a line carries at a volume of speech.
-- @param volume=0 [Number volume from -3 to 3]
-- @return [Number sound level in decibels, Number volume of the sound from 0 to 1]
function VoiceLines:get_sound_level(volume)
  volume = tonumber(volume) or 0

  if volume < 0 then
    return 75 + volume * 8, math.max(1 + volume * 0.15, 0.5)
  end

  return 75 + volume * 5, 1
end

--- Checks whether a player may play the sound of a line now, that is whether the
-- 'voice_lines_interval' config has passed since the last sound they played.
-- @param target [Player]
-- @return [Boolean]
function VoiceLines:can_play(target)
  return CurTime() >= (target.fl_next_voice_line_at or 0)
end

local function get_sound_source(target)
  if isfunction(target.get_ragdoll_entity) then
    local ragdoll = target:get_ragdoll_entity()

    if IsValid(ragdoll) then
      return ragdoll
    end
  end

  return target
end

--- Plays the sound of a line from a player, unless the player has played one within the
-- 'voice_lines_interval' config. The players nearby hear it from the speaker, and the players
-- who listen to the speaker over the radio hear it at the 'voice_lines_radio_volume' config,
-- as if from their own radio. The lines of a chain of the player play unless the chain started
-- within the interval, and a line the player says outside the chain plays only once the
-- interval has passed after the sound of the last line the chain has played has ended, see
-- `VoiceLines:start_chain`.
-- @param speaker [Player]
-- @param category [Map the category of the line]
-- @param line [Map the line]
-- @param receivers [List<Player> the players who hear the sound from the speaker]
-- @param volume=0 [Number volume of the speech from -3 to 3]
-- @param radio_listeners=nil [List<Player> the players who hear the line over the radio]
-- @return [Boolean true if the sound has been played]
function VoiceLines:play(speaker, category, line, receivers, volume, radio_listeners)
  if !IsValid(speaker) then return false end

  local chain = speaker.fl_voice_line_chain
  local chained = chain != nil and chain.current_line == line.id and chain.current_category == category.id

  if chained then
    chain.current_category, chain.current_line = nil, nil

    if chain.silent then return false end
  elseif !self:can_play(speaker) then
    return false
  end

  local gender = self:get_gender(speaker)
  local sound_path = self:get_sound(line, gender)
  local level, sound_volume = self:get_sound_level(volume)
  local filter = RecipientFilter()

  for _k, receiver in ipairs(receivers) do
    if IsValid(receiver) and receiver:IsPlayer() then
      filter:AddPlayer(receiver)
    end
  end

  get_sound_source(speaker):EmitSound(sound_path, level, 100, sound_volume, CHAN_VOICE, 0, 0, filter)

  radio_listeners = radio_listeners or {}

  if #radio_listeners > 0 then
    Cable.send(
      radio_listeners,
      'fl_voice_line_radio',
      sound_path,
      math.Clamp(tonumber(config_get('voice_lines_radio_volume')) or 0.5, 0, 1)
    )
  end

  local ends_at = CurTime()

  if chained then
    ends_at += self:get_duration(line, gender)
  end

  speaker.fl_next_voice_line_at = ends_at + (tonumber(config_get('voice_lines_interval')) or 0)

  --- Called on the server after the sound of a voice line has played.
  -- @param speaker [Player the player who has said the line]
  -- @param category [Map the category of the line]
  -- @param line [Map the line]
  -- @param receivers [List<Player> the players who have heard the sound from the speaker]
  -- @param radio_listeners [List<Player> the players who have heard it over the radio,
  --   empty if the line was not said on the radio]
  hook.Run('VoiceLinePlayed', speaker, category, line, receivers, radio_listeners)

  return true
end

--- Returns the line a player says with a phrase of in character speech: the line that
-- `VoiceLines:speak_line` is making them say, else the line the phrase matches, else the first
-- line of the chain the phrase is, see `VoiceLines:parse_chain`. A phrase that is an action
-- says no line.
-- @param actor [Player the speaker]
-- @param phrase [String the phrase without its volume markup]
-- @param no_actions=false [Boolean leave out the lines whose text is an action]
-- @return [Map the line, Map its category, List<Map> the chain when the phrase is one; nothing
--   if the phrase says no line]
function VoiceLines:find_spoken_line(actor, phrase, no_actions)
  if forced and forced.actor == actor then
    return forced.line, forced.category
  end

  if phrase:start_with('*') then return end

  local line, category = self:match(actor, phrase, no_actions)

  if line then
    return line, category
  end

  local chain = self:parse_chain(actor, phrase, no_actions)

  if chain then
    return chain[1].line, chain[1].category, chain
  end
end

--- Makes a player say a text that stands for a line, as if they had typed it into the chat
-- or, with radio, into their radio: the message says that line whatever the text is. The
-- chat guards of `Chatbox.submit`, or those of `Radios.say_radio`, apply.
-- @param actor [Player]
-- @param category [Map the category of the line]
-- @param line [Map the line]
-- @param text [String the text to say, with its volume markup]
-- @param radio=false [Boolean say it over the radio]
-- @return [Boolean true if the text has been said]
function VoiceLines:speak_line(actor, category, line, text, radio)
  forced = { actor = actor, category = category, line = line }

  local success, said

  if radio then
    success, said = pcall(Radios.say_radio, actor, text)

    if !success then
      ErrorNoHalt('[Flux - Voice Lines] Failed to say a line over the radio: '..tostring(said)..'\n')
    end
  else
    success = Chatbox.submit(actor, text)
    said = success
  end

  forced = nil

  return success and said == true
end

--- Makes a player say a line they have picked, as if they had typed its text into the chat.
-- The player has to be allowed to use the line, and the chat guards of `Chatbox.submit`
-- apply.
-- @param actor [Player]
-- @param category_id [String category ID]
-- @param line_id [String line ID]
-- @return [Boolean true if the text has been said]
function VoiceLines:say(actor, category_id, line_id)
  if !IsValid(actor) or !isstring(category_id) or !isstring(line_id) then return false end

  local category = self:find_category(category_id)
  local line = category and category.lines[line_id]

  if !line or !self:can_use(actor, category, line) then return false end

  return self:speak_line(actor, category, line, self:get_text(line, self:get_gender(actor)))
end
