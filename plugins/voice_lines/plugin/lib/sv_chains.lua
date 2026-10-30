--- Chains of voice lines on the server: once the first line of a chain has been said, the
-- next ones are said by a timer, each when the sound of the one before it has ended and the
-- pause after it has passed, through the same path as a line the player says on their own. The
-- state of the chain is kept on the player, so that a code refresh does not lose it, and a
-- player has one chain at most: a chain that starts replaces the one that is running.

if !VoiceLines then
  PLUGIN:set_global('VoiceLines')
end

--- Returns the name of the timer of the chain of a player.
-- @param actor [Player]
-- @return [String]
local function timer_name(actor)
  return 'fl_voice_line_chain_'..actor:UserID()
end

--- Returns how long the sound of a line lasts for a gender, by `SoundDuration`, or the
-- 'voice_lines_default_duration' config when the length of the sound is unknown.
-- @param line [Map]
-- @param gender=nil [String 'male', 'female' or 'no_gender']
-- @return [Number seconds]
function VoiceLines:get_duration(line, gender)
  local duration = SoundDuration(self:get_sound(line, gender))

  if !isnumber(duration) or duration <= 0 then
    return tonumber(Config.get('voice_lines_default_duration')) or 2
  end

  return duration
end

--- Waits until the line of the chain of a player that is being said has ended and the pause
-- after it has passed, then says the next one with `VoiceLines:continue_chain`.
-- @param actor [Player]
-- @param chain [Map the state of the chain]
local function schedule(actor, chain)
  local entry = chain.lines[chain.position]

  timer.Create(timer_name(actor), VoiceLines:get_duration(entry.line, VoiceLines:get_gender(actor)) + entry.pause, 1,
    function()
      VoiceLines:continue_chain(actor)
    end)
end

--- Starts a chain of lines whose first line a player is saying, see `VoiceLines:parse_chain`,
-- and replaces the chain the player has running. The sounds of the chain only play if the
-- player may play a voice line now, see `VoiceLines:can_play`; otherwise every line shows
-- its text without its sound.
-- @param actor [Player the speaker]
-- @param lines [List<Map> the chain: line, category and pause of every line]
-- @param volume=0 [Number volume of the speech from -3 to 3, kept for every line]
-- @param radio=false [Boolean whether the lines are said over the radio]
function VoiceLines:start_chain(actor, lines, volume, radio)
  if !IsValid(actor) or !istable(lines) or #lines == 0 then return end

  local chain = {
    lines = lines,
    position = 1,
    volume = tonumber(volume) or 0,
    radio = radio == true,
    silent = !self:can_play(actor),
    current = lines[1].line
  }

  actor.fl_voice_line_chain = chain

  schedule(actor, chain)
end

--- Says the next line of the chain of a player, as a message of its own at the volume of the
-- chain, or over the radio, and waits for the one after it. The chain ends once its last line
-- has been said, and it is canceled when the next line is one that the player may not use or
-- cannot say over the radio at that moment.
-- @param actor [Player]
function VoiceLines:continue_chain(actor)
  local chain = IsValid(actor) and actor.fl_voice_line_chain

  if !chain then return end

  chain.position += 1

  local entry = chain.lines[chain.position]

  if !entry or !self:can_use(actor, entry.category, entry.line) then
    self:cancel_chain(actor)

    return
  end

  local text = self:get_text(entry.line, self:get_gender(actor))

  chain.current = entry.line

  if chain.radio then
    if !Radios or !self:speak_line(actor, entry.category, entry.line, text, true) then
      self:cancel_chain(actor)

      return
    end
  else
    self:speak_line(actor, entry.category, entry.line, self:wrap_text(text, chain.volume))
  end

  if actor.fl_voice_line_chain != chain then return end

  if chain.position < #chain.lines then
    schedule(actor, chain)
  else
    actor.fl_voice_line_chain = nil
  end
end

--- Stops the chain of a player, if one is running: the lines that are left are not said.
-- The interval after the last sound that has played still applies.
-- @param actor [Player]
function VoiceLines:cancel_chain(actor)
  if !IsValid(actor) then return end

  actor.fl_voice_line_chain = nil

  timer.Remove(timer_name(actor))
end
