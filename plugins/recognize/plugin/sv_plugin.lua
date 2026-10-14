--- Server side of the Recognize plugin: keeps the stored recognitions of characters and the
-- 'fl_recognizes' networked variable in step, makes characters forget each other and
-- carries out what players ask for through the 'fl_recognize' and 'fl_recognize_forget'
-- messages.
--
-- The recognitions of the characters of connected players live in memory, in the
-- `recognizes` list of each `Character` record, and reach the database when the character
-- is saved. Whatever is forgotten is therefore removed from those lists first; the rows of
-- characters that are not loaded are deleted from the database directly.

--- Shares of the talk radius within which an introduction to a range of characters is
-- heard.
local ranges = {
  whisper = 0.25,
  talk = 1,
  yell = 2
}

local color_light_green = Color('green'):lighten(100)
local color_salmon = Color('salmon')

--- Gives up a stored recognition that has been taken off the list of its character. A
-- saved record is deleted from the database, and a record that is still being inserted is
-- marked, so that it deletes itself once it has an ID.
-- @param record [Recognize]
-- @param keep_row=false [Boolean leave the row of a saved record for the caller to delete]
local function discard(record, keep_row)
  if record.id then
    if !keep_row then
      record:destroy()
    end
  elseif record.fetched then
    record.discarded = true
  end
end

--- Deletes rows of the `recognizes` table.
-- @param conditions [Map column names to the values the deleted rows have]
-- @param except_ids=nil [List<Number> IDs of the characters whose rows are left alone.
--   They are written into the query as whole numbers rather than bound, so that a full
--   server cannot run into the limit that a database puts on bound values]
local function delete_rows(conditions, except_ids)
  local query = ActiveRecord.Database:delete('recognizes')
    for k, v in pairs(conditions) do
      query:where(k, v)
    end

    if except_ids and #except_ids > 0 then
      local ids = {}

      for k, v in ipairs(except_ids) do
        ids[k] = string.format('%d', v)
      end

      query:where_raw(query:quote_column('character_id')..' NOT IN ('..table.concat(ids, ', ')..')')
    end
  query:execute()
end

--- Returns the distance at which characters hear normal speech: the `talk_radius` config
-- of the RP Commands plugin, which introductions to a range of characters are measured by.
-- @return [Number distance in units]
function Recognizes:get_talk_radius()
  return tonumber(Config.get('talk_radius')) or 350
end

--- Networks the recognitions that the active character of a player has stored to the
-- clients, as the 'fl_recognizes' variable of the player.
-- @param owner [Player]
function Recognizes:sync(owner)
  local character = owner:get_character()
  local names = {}

  if character and istable(character.recognizes) then
    for k, v in ipairs(character.recognizes) do
      names[v.target_id] = v.name
    end
  end

  owner:set_nv('fl_recognizes', names)
end

--- Removes stored recognitions from a character that is loaded. The networked variable of
-- its player is not updated: call `Recognizes:sync` afterwards if the character is active.
-- @param character [Character]
-- @param target_id=nil [Number ID of the character to forget; nil forgets every character]
-- @param name=nil [String only forget characters that are known by this name]
-- @return [Number how many recognitions were removed]
function Recognizes:remove_records(character, target_id, name)
  local records = character and character.recognizes

  if !istable(records) then return 0 end

  local count = 0

  for i = #records, 1, -1 do
    local record = records[i]

    if (!target_id or tonumber(record.target_id) == target_id) and (!name or record.name == name) then
      discard(record)

      table.remove(records, i)

      count = count + 1
    end
  end

  return count
end

--- Removes every stored recognition from a character that is loaded, with a single query.
-- The networked variable of its player is not updated: call `Recognizes:sync` afterwards
-- if the character is active.
-- @param character [Character]
-- @return [Number how many recognitions were removed]
function Recognizes:clear_records(character)
  local records = character and character.recognizes

  if !istable(records) then return 0 end

  for k, v in ipairs(records) do
    discard(v, true)
  end

  character.recognizes = {}

  if character.id then
    delete_rows({ character_id = character.id })
  end

  return #records
end

--- Makes every character forget a character: the characters of connected players, active
-- or not, and those in the database.
-- ```
-- -- Everyone who knows the character by its real name forgets it.
-- Recognizes:forget_character(target:get_character_id(), target:name(true))
-- ```
-- @param character_id [Number ID of the character to forget]
-- @param name=nil [String only those who know the character by this name forget it]
-- @return [Number how many characters of connected players have forgotten it]
function Recognizes:forget_character(character_id, name)
  character_id = tonumber(character_id)

  if !character_id then return 0 end

  local loaded_ids = {}
  local count = 0

  for k, v in player.Iterator() do
    local characters = istable(v.record) and v.record.characters

    if istable(characters) then
      local active = v:get_character()

      for k2, character in pairs(characters) do
        local removed = self:remove_records(character, character_id, name)
        local loaded_id = tonumber(character.id)

        if loaded_id then
          loaded_ids[#loaded_ids + 1] = loaded_id
        end

        if removed > 0 then
          count = count + removed

          if character == active then
            self:sync(v)
          end
        end
      end
    end
  end

  local conditions = { target_id = character_id }

  if name then
    conditions.name = name
  end

  delete_rows(conditions, loaded_ids)

  return count
end

--- Turns the name a player has asked to be known by into one that can be stored: control
-- characters become spaces, the name is trimmed and cut to `Recognizes.max_name_length`
-- characters.
-- @param name [String]
-- @return [String the name, or nil if nothing is left of it or it is not valid UTF-8]
function Recognizes:clean_name(name)
  if !isstring(name) then return end

  name = string.Trim((name:gsub('%c', ' ')))

  local length = utf8.len(name)

  if !isnumber(length) or length == 0 then return end

  if length > self.max_name_length then
    name = string.Trim(name:utf8sub(1, self.max_name_length))
  end

  return name
end

--- Checks whether a player may ask to introduce themselves or to forget someone right
-- now: the recognition system is on, their last request is at least half a second old,
-- and they are alive and have a character. A player who is dead or has no character is
-- told that they cannot do it now.
-- @param actor [Player]
-- @return [Boolean]
function Recognizes:accept_request(actor)
  if !self:is_enabled() or !IsValid(actor) then return false end

  local cur_time = CurTime()

  if actor.next_recognize_request and actor.next_recognize_request > cur_time then
    return false
  end

  actor.next_recognize_request = cur_time + 0.5

  if !actor:Alive() or !actor:is_character_loaded() then
    actor:notify('error.cant_now')

    return false
  end

  return true
end

--- Introduces a player to the player they look at or to everyone within a range, which
-- makes those characters know the player by the given name. Everyone involved is notified.
-- An introduction can be refused for each listener by the PlayerCanRecognize hook, and
-- players who have no character loaded learn nothing.
-- @param actor [Player player who introduces themselves]
-- @param kind [String 'target' for a single player, or 'whisper', 'talk' or 'yell' for
--   everyone within that range]
-- @param name=nil [String name to be known by, the real name of the character if it is
--   not a string]
-- @param target=nil [Player player to introduce to when the kind is 'target'; the player
--   the actor looks at if it is nil or false. A target that is no longer valid gets no
--   introduction]
-- @return [Boolean false if the request was not valid]
function Recognizes:introduce(actor, kind, name, target)
  local real_name = actor:name(true)
  local radius = self:get_talk_radius()
  local targets = {}

  if isstring(name) and name != real_name then
    name = self:clean_name(name)

    if !name then
      actor:notify('error.recognize.invalid_name')

      return false
    end
  else
    name = real_name
  end

  if kind == 'target' then
    if !target then
      target = actor:GetEyeTraceNoCursor().Entity
    end

    local reach = radius * 4

    if isentity(target) and IsValid(target) and target:IsPlayer() and
    target:EyePos():DistToSqr(actor:EyePos()) <= reach * reach then
      targets[1] = target
    end
  elseif isstring(kind) and ranges[kind] then
    local distance = radius * ranges[kind]
    local distance_sqr = distance * distance
    local eye_pos = actor:EyePos()

    for k, v in player.Iterator() do
      if eye_pos:DistToSqr(v:EyePos()) <= distance_sqr then
        targets[#targets + 1] = v
      end
    end
  else
    return false
  end

  for i = 1, #targets do
    local listener = targets[i]

    --- Asks whether a player may learn the name that another player introduces
    -- themselves under. Called on the server for every player an introduction reaches,
    -- the one who introduces themselves included. The Recognize plugin refuses it for
    -- that player and, if the `recog_must_see` config is on, for players who have no
    -- clear line of sight to them.
    -- @param actor [Player the player who introduces themselves]
    -- @param target [Player the player who would learn the name]
    -- @return [Boolean return false to keep the target from learning the name]
    if hook.Run('PlayerCanRecognize', actor, listener) != false and listener:is_character_loaded() then
      local is_known, known_name = listener:recognizes(actor)

      if !listener:knows_real_name(actor) then
        if !is_known then
          listener:notify('notification.recognize.new_name', { name = tostring(name) }, color_light_green)
        else
          listener:notify('notification.recognize.change_name', {
            name = tostring(known_name),
            new_name = tostring(name)
          }, color_salmon)
        end
      end

      listener:add_recognize(actor, name)
    end
  end

  if name == real_name then
    actor:notify('notification.recognize.true_name', { name = tostring(name) }, color_light_green)
  else
    actor:notify('notification.recognize.false_name', { name = tostring(name) }, color_salmon)
  end

  return true
end

--- Makes the character of a player forget the character of another player because the
-- player has asked for it, and tells them so. The PlayerCanForget hook can refuse it.
-- @param actor [Player player who wants to forget]
-- @param target [Player player to forget]
-- @return [Boolean whether the target was forgotten]
function Recognizes:player_forget(actor, target)
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or actor == target then return false end

  local known_name = actor:get_recognize(target)

  if !known_name then return false end

  --- Asks whether a player may forget another player of their own accord. Called on the
  -- server when a player picks the forget option for someone their character has stored.
  -- Not called when staff or a death make a character forget.
  -- @param actor [Player the player who wants to forget]
  -- @param target [Player the player who would be forgotten]
  -- @return [Boolean return false to keep the actor from forgetting the target]
  if hook.Run('PlayerCanForget', actor, target) == false then return false end

  if !actor:remove_recognize(target) then return false end

  actor:notify('notification.recognize.forgotten', { name = tostring(known_name) }, color_salmon)

  return true
end

Cable.receive('fl_recognize', function(actor, kind, name, target)
  if Recognizes:accept_request(actor) then
    Recognizes:introduce(actor, kind, name, target)
  end
end)

Cable.receive('fl_recognize_forget', function(actor, target)
  if Recognizes:accept_request(actor) then
    Recognizes:player_forget(actor, target)
  end
end)
