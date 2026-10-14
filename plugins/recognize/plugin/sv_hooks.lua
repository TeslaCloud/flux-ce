--- Server-side hooks of the Recognize plugin: networks the recognitions of a loaded
-- character, decides who an introduction reaches, erases recognitions when a character
-- dies or is deleted and names the characters on the access lists of doors.

--- Networks the names a character recognizes others by once it is loaded.
-- @param owner [Player player the character belongs to]
-- @param character [Character loaded character]
function Recognizes:PostCharacterLoaded(owner, character)
  self:sync(owner)
end

--- Prevents players from recognizing themselves or, if recog_must_see is set, players they cannot see.
-- @param actor [Player player introducing themselves]
-- @param target [Player player that would recognize them]
-- @return [Boolean false to prevent recognizing, nil otherwise]
function Recognizes:PlayerCanRecognize(actor, target)
  if actor == target then
    return false
  end

  if Config.get('recog_must_see') and util.vector_obstructed(actor:EyePos(), target:EyePos(), { actor, target }) then
    return false
  end
end

--- Erases recognitions when a character dies, as the configs ask for: the character
-- forgets everyone (`recog_forget_on_death`), and everyone who knew the character by its
-- real name forgets it (`recog_forgotten_on_death`). Nothing happens while the
-- recognition system is off.
-- @param victim [Player]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function Recognizes:PlayerDeath(victim, inflictor, attacker)
  if !self:is_enabled() or victim:IsBot() or !victim:is_character_loaded() then return end

  if Config.get('recog_forget_on_death') and victim:clear_recognizes() > 0 then
    victim:notify('notification.recognize.forgot_everyone', nil, Color('salmon'))
  end

  if Config.get('recog_forgotten_on_death') then
    self:forget_character(victim:get_character_id(), victim:name(true))
  end
end

--- Deletes the recognitions of a character that is about to be deleted, and makes every
-- other character forget it.
-- @param actor [Player player who deletes the character]
-- @param id [Number ID of the character]
-- @param character [Character the character that is about to be deleted]
function Recognizes:OnCharacterDelete(actor, id, character)
  self:clear_records(character)
  self:forget_character(id)
end

--- Puts a character on the access list of a door under the name that the player who gives
-- the access knows it by, so that the list does not give away a real name. A stranger is
-- listed by the start of their physical description.
-- @param actor [Player the player who gives the access]
-- @param target [Player the player whose active character receives it]
-- @param entity [Entity the door, or the main door of its group]
-- @return [String the name to list the character under, nil while the recognition system
--   is off]
function Recognizes:GetDoorAccessName(actor, target, entity)
  if !self:is_enabled() then return end

  return self:get_known_name(actor, target)
end
