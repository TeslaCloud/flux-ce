--- Levels and experience of characters, the points that level-ups grant and the maximum
-- health that grows with the level, together with the player methods that read and change
-- them.
--
-- The level and the experience of a character live in its `level` and `experience` fields
-- on the server, and the server networks them to the owner of the character alone, in the
-- private 'level' and 'experience' networked variables, which the getters read on the
-- client. The skill and attribute points that have not been spent yet are kept in the
-- `skill_points` and `attribute_points` character data, which the owner receives as well,
-- and the points spent so far in `skill_points_spent` and `attribute_points_spent`, which
-- stay on the server. What is unspent is always worked out from the level: the points the
-- level has earned minus the points already spent, never less than zero.
--
-- The server level grows with the real time since the plugin first ran on the server, which
-- the server keeps together with the last server level it has seen in the
-- 'schemas/<schema folder>/levels' data file (see `Data.save`), shared by every map of the
-- schema so that a map change keeps the server level. The server networks the time of that
-- first run and the server level to every player in the public 'levels_first_boot' and
-- 'levels_server_level' networked globals. The client takes the server level from there and
-- works out how far it is into it with its own clock.
--
-- This file is included before sh_plugin.lua, which is why it is the one that makes the
-- plugin available as the `Levels` global.

local IsValid = IsValid
local isstring = isstring
local istable = istable
local tonumber = tonumber
local config_get = Config.get
local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_round = math.Round
local os_time = os.time

local seconds_per_day = 86_400

if !Levels then
  PLUGIN:set_global('Levels')
end

Characters.network_data('skill_points')
Characters.network_data('attribute_points')

local function get_whole_config(key, default, min)
  local value = tonumber(config_get(key, default))

  if !value or value != value then
    value = default
  end

  return math_max(math_floor(value), min)
end

local function get_number_config(key, default, min)
  local value = tonumber(config_get(key, default))

  if !value or value != value then
    value = default
  end

  return math_max(value, min)
end

--- Returns the highest level a character can reach, the `levels_max_level` config.
-- @return [Number never lower than 1]
function Levels.get_max_level()
  return get_whole_config('levels_max_level', 20, 1)
end

--- Returns the experience needed to go from a level to the next one: the
-- `levels_experience_per_level` config, the same for every level. A character at the
-- highest level has no next level to gather experience for.
-- @param level [Number level to go up from]
-- @return [Number experience; 0 when the level is the highest one or above it]
function Levels.get_experience_for_level(level)
  level = tonumber(level) or 1

  if level >= Levels.get_max_level() then
    return 0
  end

  return get_whole_config('levels_experience_per_level', 1000, 1)
end

--- Returns the skill points that a character has earned by reaching a level:
-- `levels_skill_points_per_level` for every level after the first.
-- @param level [Number]
-- @return [Number]
function Levels.get_skill_points_for_level(level)
  local per_level = get_whole_config('levels_skill_points_per_level', 1, 0)

  return math_max(math_floor(tonumber(level) or 1) - 1, 0) * per_level
end

--- Returns the attribute points that a character has earned by reaching a level:
-- `levels_boost_points` for every `levels_boost_every` levels, so with the defaults 2
-- points at levels 5, 10, 15 and 20.
-- @param level [Number]
-- @return [Number]
function Levels.get_attribute_points_for_level(level)
  local every = get_whole_config('levels_boost_every', 5, 0)

  if every < 1 then return 0 end

  local points = get_whole_config('levels_boost_points', 2, 0)

  return math_floor(math_max(math_floor(tonumber(level) or 1), 0) / every) * points
end

--- Returns the maximum health of a player's character:
-- `health_base + (level - 1) * health_per_level + level * endurance`, where endurance is
-- the level of the 'endurance' stat with its boosts, or 0 when no such stat is registered.
-- With the defaults a level 1 character of endurance 0 has 10 health and gains 3 for each
-- level after that.
-- @param target [Player]
-- @return [Number whole number, never lower than 1]
function Levels:get_max_health(target)
  local level = target:get_level()
  local endurance = tonumber((target:get_attribute('endurance'))) or 0
  local base = get_whole_config('health_base', 10, 1)
  local per_level = get_whole_config('health_per_level', 3, 0)

  return math_max(math_floor(base + (level - 1) * per_level + level * endurance), 1)
end

--- Checks whether the server level limits the levels of characters, which is what the
-- `levels_server_progression` config turns on. While it is off there is no level cap and
-- no level floor.
-- @return [Boolean]
function Levels.is_server_progression_enabled()
  return config_get('levels_server_progression', true) != false
end

--- Returns how long the server takes to reach a level from the one before it: the
-- `levels_server_days_per_level` config (7 days) for every level below the
-- `levels_server_ramp_level` config (4), and from that level on the `levels_server_ramp_days`
-- config (1 day) more for each level past the one before it, so with the defaults level 4
-- takes 8 days, level 5 9 days and level n 7 + (n - 3) days. Level -1, where the server
-- starts, takes no time.
-- @param level [Number the level that is reached]
-- @return [Number seconds]
function Levels.get_seconds_for_server_level(level)
  level = math_floor(tonumber(level) or 0)

  if level != level or level < 0 then return 0 end

  local days = get_number_config('levels_server_days_per_level', 7, 0.01)
  local ramp_level = get_whole_config('levels_server_ramp_level', 4, 1)

  if level >= ramp_level then
    days += (level - ramp_level + 1) * get_number_config('levels_server_ramp_days', 1, 0)
  end

  return days * seconds_per_day
end

--- Returns how long the server takes from its first run to reach a level: the time of
-- every step from level -1 up to that level.
-- @param level [Number the level that is reached; no higher than the highest level counts]
-- @return [Number seconds; 0 for level -1]
function Levels.get_seconds_to_server_level(level)
  level = math_min(math_floor(tonumber(level) or -1), Levels.get_max_level())

  local total = 0

  for i = 0, level do
    total += Levels.get_seconds_for_server_level(i)
  end

  return total
end

--- Returns the level the server is at after some time has passed since its first run.
-- ```
-- Levels.get_server_level_at(0)            -- -1
-- Levels.get_server_level_at(7 * 86400)    -- 0
-- Levels.get_server_level_at(36 * 86400)   -- 4
-- ```
-- @param elapsed_seconds [Number seconds since the first run]
-- @return [Number from -1 to the highest level a character can reach]
function Levels.get_server_level_at(elapsed_seconds)
  local elapsed = tonumber(elapsed_seconds) or 0

  if elapsed != elapsed or elapsed < 0 then
    elapsed = 0
  end

  local max_level = Levels.get_max_level()
  local level = -1

  while level < max_level do
    local step = Levels.get_seconds_for_server_level(level + 1)

    if elapsed < step then break end

    elapsed -= step
    level += 1
  end

  return level
end

--- Returns the time the plugin first ran on the server. The client knows it once the server
-- has networked it.
-- @return [Number unix time, nil if it is not known yet]
function Levels.get_first_boot()
  if SERVER then
    return Levels.first_boot
  end

  return tonumber(ActiveNetwork.get_nv('levels_first_boot'))
end

--- Returns the seconds since the plugin first ran on the server, by the clock of the realm
-- that asks.
-- @return [Number never lower than 0; 0 while the first run is not known]
local function get_elapsed()
  local first_boot = Levels.get_first_boot()

  if !first_boot then return 0 end

  return math_max(os_time() - first_boot, 0)
end

--- Returns the level of the server, which rises with the real time since the plugin first
-- ran on it, see `Levels.get_seconds_for_server_level`. On the client this is the level the
-- server has networked.
-- @return [Number from -1 to the highest level a character can reach; -1 while the first run
--   is not known]
function Levels.get_server_level()
  local max_level = Levels.get_max_level()

  if CLIENT then
    return math_clamp(math_floor(tonumber(ActiveNetwork.get_nv('levels_server_level')) or -1), -1, max_level)
  end

  if !Levels.first_boot then return -1 end

  return Levels.get_server_level_at(get_elapsed())
end

--- Returns how far the server is into its current level.
-- @return [Number seconds spent at the current level, Number seconds the step to the next
--   level takes; both 0 at the highest level]
function Levels.get_server_level_progress()
  local level = Levels.get_server_level()

  if level >= Levels.get_max_level() then
    return 0, 0
  end

  local step = Levels.get_seconds_for_server_level(level + 1)

  return math_clamp(get_elapsed() - Levels.get_seconds_to_server_level(level), 0, step), step
end

--- Returns the time until the server reaches its next level.
-- @return [Number seconds, nil at the highest level]
function Levels.get_server_level_eta()
  if Levels.get_server_level() >= Levels.get_max_level() then return end

  local elapsed, step = Levels.get_server_level_progress()

  return math_max(step - elapsed, 0)
end

--- Returns the highest level a character can reach through experience: the server level
-- plus the `levels_server_cap_offset` config (2). Experience gathered at the cap is kept
-- until the cap rises. Staff commands are not bound by it.
-- @return [Number between 1 and the highest level; the highest level while the
--   `levels_server_progression` config is off]
function Levels.get_level_cap()
  local max_level = Levels.get_max_level()

  if !Levels.is_server_progression_enabled() then
    return max_level
  end

  return math_clamp(Levels.get_server_level() + get_whole_config('levels_server_cap_offset', 2, 0), 1, max_level)
end

--- Returns the lowest level a character may have: the server level minus the
-- `levels_server_floor_offset` config (2). Characters below it are raised to it.
-- @return [Number between 1 and the level cap; 1 while the `levels_server_progression`
--   config is off]
function Levels.get_level_floor()
  if !Levels.is_server_progression_enabled() then return 1 end

  return math_clamp(Levels.get_server_level() - get_whole_config('levels_server_floor_offset', 2, 0), 1,
    Levels.get_level_cap())
end

--- Raises a level for every time the experience covers what the level needs, taking that
-- experience away each time, as far as a cap.
-- @param level [Number level to start from]
-- @param experience [Number experience to spend]
-- @param cap [Number level not to go past; the highest level is never passed]
-- @return [Number level reached, Number experience left]
local function advance(level, experience, cap)
  cap = math_min(cap, Levels.get_max_level())

  while level < cap do
    local needed = Levels.get_experience_for_level(level)

    if needed <= 0 or experience < needed then break end

    experience -= needed
    level += 1
  end

  return level, experience
end

if SERVER then
  --- Returns the active character of a player, if they have one.
  -- @param target [Player]
  -- @return [Character/Map the character record, or the stand-in table of a bot; nil if the
  --   player is not valid or has no active character]
  local function get_character(target)
    if !IsValid(target) or !target:is_character_loaded() then return end

    local character = target:get_character()

    return istable(character) and character or nil
  end

  local function get_stored_level(character)
    local level = tonumber(character.level) or 1

    return math_clamp(math_floor(level), 1, Levels.get_max_level())
  end

  local function get_stored_experience(character)
    return math_max(math_floor(tonumber(character.experience) or 0), 0)
  end

  --- Networks the level and the experience of a player's character to that player, in the
  -- private 'level' and 'experience' networked variables. Called after every change the
  -- plugin makes and when a character becomes active; call it yourself after changing the
  -- fields of the character directly. Server only.
  -- @param target [Player]
  function Levels.sync(target)
    local character = get_character(target)

    if !character then return end

    target:set_private_nv('level', get_stored_level(character))
    target:set_private_nv('experience', get_stored_experience(character))
  end

  --- Works out the unspent skill and attribute points of a player's character from its
  -- level and stores them in the `skill_points` and `attribute_points` character data: the
  -- points the level has earned minus the points spent so far, never less than zero. Points
  -- that were spent stay spent when the level goes down. Server only.
  -- @param target [Player]
  function Levels.update_points(target)
    if !get_character(target) then return end

    local level = target:get_level()
    local skill_points = math_max(Levels.get_skill_points_for_level(level) -
      (tonumber(target:get_character_data('skill_points_spent')) or 0), 0)
    local attribute_points = math_max(Levels.get_attribute_points_for_level(level) -
      (tonumber(target:get_character_data('attribute_points_spent')) or 0), 0)

    if target:get_character_data('skill_points') != skill_points then
      target:set_character_data('skill_points', skill_points)
    end

    if target:get_character_data('attribute_points') != attribute_points then
      target:set_character_data('attribute_points', attribute_points)
    end
  end

  --- Sets the level and the experience of a player's character, works out its unspent
  -- points again, networks the change and runs the PlayerExperienceChanged hook, followed
  -- by PlayerLevelChanged when the level has changed. A character at the highest level
  -- keeps no experience; below it the experience may be more than the level needs, which is
  -- how a character at the level cap keeps what it gathers until the cap rises. Neither the
  -- level cap nor the level floor is applied here. Nothing happens if neither value changes.
  -- Server only.
  -- @param target [Player]
  -- @param level [Number new level, rounded and kept between 1 and the highest level]
  -- @param experience [Number new experience toward the next level, rounded down and never
  --   lower than 0]
  -- @param reason=nil [String what the change is for, passed on to the hook]
  -- @return [Boolean true if the level or the experience has changed]
  function Levels.update(target, level, experience, reason)
    local character = get_character(target)

    if !character then return false end

    local max_level = Levels.get_max_level()

    level = tonumber(level) or 1
    experience = tonumber(experience) or 0

    if level != level or experience != experience then return false end

    level = math_clamp(math_round(level), 1, max_level)
    experience = level >= max_level ? 0 : math_max(math_floor(experience), 0)

    local old_level = get_stored_level(character)
    local old_experience = get_stored_experience(character)

    if level == old_level and experience == old_experience then return false end

    character.level = level
    character.experience = experience

    Levels.update_points(target)
    Levels.sync(target)

    --- Called on the server after the level or the experience of a player's character has
    -- changed and the change has been networked, however it came about: through
    -- `Player:give_experience`, `Player:set_level` or the staff commands. A call that moves
    -- the character over several levels runs the hook once.
    -- @param actor [Player The player whose character it is]
    -- @param experience [Number New experience toward the next level, which may be more than
    --   the level needs while the character is at the level cap]
    -- @param old [Number Experience toward the next level before the change, which may have
    --   been a lower level]
    -- @param reason [String What the experience was given for: 'damage' and 'kill' for
    --   combat experience, 'command' for the `experience add` command, 'level_set' when
    --   the level was set, 'catch_up' when the level cap has risen and kept experience was
    --   spent, 'level_floor' when the character was raised to the level floor, or whatever
    --   the caller of `Player:give_experience` passed; may be nil]
    hook.Run('PlayerExperienceChanged', target, experience, old_experience, reason)

    if level != old_level then
      --- Called on the server after the level of a player's character has changed, right
      -- after PlayerExperienceChanged. Its unspent points have already been worked out
      -- again. A call that moves the character over several levels runs the hook once. The
      -- Levels plugin applies the new maximum health from its own handler.
      -- @param actor [Player The player whose character it is]
      -- @param level [Number New level]
      -- @param old_level [Number Level before the change]
      hook.Run('PlayerLevelChanged', target, level, old_level)
    end

    return true
  end

  --- Sets the maximum health of a player to `Levels:get_max_health`. Their health is cut
  -- down to it if it is higher, or set to it if asked to refill. Nothing happens to a player
  -- without an active character. Server only.
  -- @param target [Player]
  -- @param refill=false [Boolean also fill the health of the player up to the maximum]
  -- @return [Number the maximum health applied, or nil if nothing was done]
  function Levels:apply_max_health(target, refill)
    if !get_character(target) then return end

    local max_health = self:get_max_health(target)

    target:SetMaxHealth(max_health)

    if refill or target:Health() > max_health then
      target:SetHealth(max_health)
    end

    return max_health
  end

  --- Levels up a player's character as far as its kept experience and the level cap allow,
  -- taking the experience each level needs, and tells the player about the level reached.
  -- Called when the level cap rises and when a character becomes active. Server only.
  -- @param target [Player]
  -- @return [Boolean true if the character has gone up]
  function Levels.catch_up(target)
    local character = get_character(target)

    if !character then return false end

    local old_level = get_stored_level(character)
    local level, experience = advance(old_level, get_stored_experience(character), Levels.get_level_cap())

    if level <= old_level or !Levels.update(target, level, experience, 'catch_up') then return false end

    target:notify('notification.levels.level_up', { level = level })

    return true
  end

  --- Raises a player's character to the level floor if it is below it, keeping its
  -- experience as it is, and tells the player about the level reached. Server only.
  -- @param target [Player]
  -- @return [Boolean true if the character was raised]
  function Levels.raise_to_floor(target)
    local character = get_character(target)

    if !character then return false end

    local level = Levels.get_level_floor()

    if get_stored_level(character) >= level then return false end

    if !Levels.update(target, level, get_stored_experience(character), 'level_floor') then return false end

    target:notify('notification.levels.level_up', { level = level })

    return true
  end

  --- Brings a player's character in line with the server level: first raises it to the
  -- level floor (`Levels.raise_to_floor`), which keeps its experience, then spends its kept
  -- experience on levels as far as the level cap allows (`Levels.catch_up`). The levels the
  -- floor grants cost no experience, and since the floor is never above the cap, the
  -- experience is never spent past the cap. Server only.
  -- @param target [Player]
  -- @return [Boolean true if the level has changed]
  function Levels.apply_server_level(target)
    local raised = Levels.raise_to_floor(target)
    local caught_up = Levels.catch_up(target)

    return raised or caught_up
  end

  --- Returns the key of the data file of the server level: 'schemas/<schema folder>/levels',
  -- the same for every map of the schema, with 'flux' as the folder when no schema is
  -- loaded.
  -- @return [String key for `Data.save` and `Data.load`]
  local function get_data_key()
    return 'schemas/'..(Flux.get_schema_folder() or 'flux')..'/levels'
  end

  --- Loads the saved data of the server level of the schema.
  -- @return [Map first_boot (Number unix time) and level (Number last server level seen);
  --   empty if nothing was saved yet]
  local function read_server_data()
    local data = Data.load(get_data_key(), {})

    return istable(data) and data or {}
  end

  local function save_server_data()
    Data.save(get_data_key(), {
      first_boot = Levels.first_boot,
      level = Levels.last_server_level
    })
  end

  --- Works out the server level, networks it to every player and runs the
  -- ServerLevelChanged hook when it differs from the last one seen, which is saved with the
  -- time of the first run so that a change while the server was off is reported on the next
  -- start. The plugin calls it on start, once a minute and when a config of the server
  -- level changes. Does nothing before `Levels.load_server_data`. Server only.
  -- @return [Number the server level]
  function Levels.check_server_level()
    if !Levels.first_boot then return -1 end

    local level = Levels.get_server_level()
    local old_level = Levels.last_server_level or level

    ActiveNetwork.set_nv('levels_server_level', level)

    if level == Levels.last_server_level then return level end

    Levels.last_server_level = level

    save_server_data()

    if level != old_level then
      --- Called on the server when the server level has changed, because time has passed,
      -- because staff set it, or because a config of the server level was changed. The
      -- new level has already been networked. The Levels plugin levels characters up to the
      -- new level cap with their kept experience and raises them to the new level floor from
      -- its own handler.
      -- @param level [Number New server level]
      -- @param old_level [Number Server level before the change]
      hook.Run('ServerLevelChanged', level, old_level)
    end

    return level
  end

  --- Loads the time the plugin first ran on the server and the last server level seen, saving
  -- the current time as the first run if none was saved yet, networks the first run and
  -- checks the server level. The plugin calls it from its LoadData handler. Server only.
  function Levels.load_server_data()
    local data = read_server_data()
    local first_boot = tonumber(data.first_boot)
    local level = tonumber(data.level)

    Levels.first_boot = first_boot

    if !first_boot or first_boot != first_boot then
      Levels.first_boot = os_time()
    end

    Levels.last_server_level = level or Levels.get_server_level()

    if Levels.first_boot != first_boot or level == nil then
      save_server_data()
    end

    ActiveNetwork.set_nv('levels_first_boot', Levels.first_boot)

    Levels.check_server_level()
  end

  --- Sets the time the plugin first ran on the server, which the server level is counted
  -- from, saves it, networks it and checks the server level. Server only.
  -- @param unix_time [Number unix time, rounded down]
  -- @return [Boolean false if the time is not a number]
  function Levels.set_first_boot(unix_time)
    unix_time = tonumber(unix_time)

    if !unix_time or unix_time != unix_time then return false end

    Levels.first_boot = math_floor(unix_time)

    save_server_data()
    ActiveNetwork.set_nv('levels_first_boot', Levels.first_boot)

    Levels.check_server_level()

    return true
  end

  --- Puts the server at the very start of a level by moving the time of its first run back
  -- by as long as reaching that level takes, see `Levels.set_first_boot`. The
  -- ServerLevelChanged hook runs if the level differs from the one before. Server only.
  -- ```
  -- Levels.set_server_level(3)
  -- ```
  -- @param level [Number rounded and kept between -1 and the highest level]
  -- @return [Boolean false if the level is not a number]
  function Levels.set_server_level(level)
    level = tonumber(level)

    if !level or level != level then return false end

    level = math_clamp(math_round(level), -1, Levels.get_max_level())

    return Levels.set_first_boot(os_time() - Levels.get_seconds_to_server_level(level))
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the level of the player's character. On the client this is what the server has
  -- networked, which it does for the local player alone.
  -- @return [Number between 1 and the highest level; 1 when the player has no character or,
  --   on the client, is not the local player]
  function player_meta:get_level()
    local level

    if CLIENT then
      level = self:get_nv('level')
    elseif self:is_character_loaded() then
      local character = self:get_character()

      level = istable(character) and character.level
    end

    return math_clamp(math_floor(tonumber(level) or 1), 1, Levels.get_max_level())
  end

  --- Returns the experience the player's character has gathered toward its next level,
  -- which may be more than the level needs while the character is at the level cap. On the
  -- client this is what the server has networked, which it does for the local player alone.
  -- @return [Number; 0 when the player has no character, is at the highest level or, on the
  --   client, is not the local player]
  function player_meta:get_experience()
    local experience

    if CLIENT then
      experience = self:get_nv('experience')
    elseif self:is_character_loaded() then
      local character = self:get_character()

      experience = istable(character) and character.experience
    end

    return math_max(math_floor(tonumber(experience) or 0), 0)
  end

  --- Returns the experience the player's character still needs to reach its next level.
  -- @return [Number; 0 at the highest level]
  function player_meta:get_experience_to_level()
    return math_max(Levels.get_experience_for_level(self:get_level()) - self:get_experience(), 0)
  end

  --- Returns the skill points of the player's character that have not been spent yet. On the
  -- client only the local player's points are known.
  -- @return [Number]
  function player_meta:get_skill_points()
    return math_max(tonumber(self:get_character_data('skill_points', 0)) or 0, 0)
  end

  --- Returns the attribute points of the player's character that have not been spent yet. On
  -- the client only the local player's points are known.
  -- @return [Number]
  function player_meta:get_attribute_points()
    return math_max(tonumber(self:get_character_data('attribute_points', 0)) or 0, 0)
  end

  if SERVER then
    --- Gives the player's character experience. Whenever the experience reaches what the
    -- level needs, the character goes up a level and keeps the rest, as many times as the
    -- amount allows, but never past the level cap (`Levels.get_level_cap`): a character at
    -- the cap keeps all the experience it is given, even more than the level needs, and
    -- spends it on levels once the cap rises (`Levels.catch_up`). A negative amount takes
    -- experience away and takes levels back once the experience falls below 0, down to level
    -- 1. At the highest level no experience is kept. The player is told about every level
    -- gained. Server only.
    -- ```
    -- target:give_experience(250, 'quest')
    -- ```
    -- @param amount [Number experience, rounded; negative to take experience away]
    -- @param reason=nil [String what the experience is for, passed on to the
    --   PlayerExperienceChanged hook]
    -- @param ignore_cap=false [Boolean level up past the level cap, as far as the highest
    --   level; the staff commands do this]
    -- @return [Boolean true if the level or the experience has changed]
    -- @see [Levels.update]
    function player_meta:give_experience(amount, reason, ignore_cap)
      amount = tonumber(amount)

      if !amount or amount != amount or !self:is_character_loaded() then return false end

      amount = math_round(amount)

      if amount == 0 then return false end

      local old_level = self:get_level()
      local cap = ignore_cap and Levels.get_max_level() or Levels.get_level_cap()
      local level, experience = advance(old_level, self:get_experience() + amount, cap)

      while experience < 0 and level > 1 do
        level -= 1
        experience += Levels.get_experience_for_level(level)
      end

      if !Levels.update(self, level, experience, reason) then return false end

      if level > old_level then
        self:notify('notification.levels.level_up', { level = level })
      end

      return true
    end

    --- Sets the level of the player's character and resets its experience to 0. The
    -- unspent skill and attribute points are worked out again for the new level, so they
    -- grow or shrink with it; points that were already spent stay spent. Server only.
    -- @param level [Number new level, rounded and kept between 1 and the highest level]
    -- @return [Boolean true if the level or the experience has changed]
    -- @see [Levels.update]
    function player_meta:set_level(level)
      level = tonumber(level)

      if !level then return false end

      local changed = Levels.update(self, level, 0, 'level_set')

      Levels.update_points(self)

      return changed
    end

    --- Spends one unspent point on a skill or a stat, raising it by one.
    -- @param target [Player]
    -- @param id [String ID of the skill or the stat]
    -- @param pool_key [String character data key of the unspent points]
    -- @param handlers [Map functions that work on the skill or the stat: find (taking the ID
    --   and returning the definition, nil if it is not registered), get (taking the player
    --   and the ID and returning the Number current value without boosts) and raise (taking
    --   the player and the ID and raising the value by one)]
    -- @param errors [Map phrases to return: invalid, empty and maxed]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise]
    local function spend_point(target, id, pool_key, handlers, errors)
      if !target:is_character_loaded() then
        return false, 'error.levels.no_active_character'
      end

      local definition = isstring(id) and handlers.find(id)

      if !definition or definition.hidden then
        return false, errors.invalid
      end

      local points = math_max(tonumber(target:get_character_data(pool_key, 0)) or 0, 0)

      if points <= 0 then
        return false, errors.empty
      end

      local value = handlers.get(target, id)

      if value >= definition.max then
        return false, errors.maxed
      end

      handlers.raise(target, id)

      if handlers.get(target, id) <= value then
        return false, 'error.levels.cannot_raise'
      end

      local spent_key = pool_key..'_spent'

      target:set_character_data(pool_key, points - 1)
      target:set_character_data(spent_key, (tonumber(target:get_character_data(spent_key, 0)) or 0) + 1)

      return true
    end

    local skill_handlers = {
      find = id -> Skills.find(id),
      get = |target, id| -> target:get_skill(id),
      raise = function(target, id) target:increase_skill(id, 1) end
    }

    local attribute_handlers = {
      find = id -> Attributes.find(id),
      get = |target, id| -> target:get_attribute(id, true),
      raise = function(target, id) target:increase_attribute(id, 1) end
    }

    --- Spends one unspent skill point of the player's character on a skill of the Stats
    -- plugin, raising it by one rank. Refused when the skill is not registered or is hidden,
    -- the character has no skill points left or the skill is at its highest rank. Server
    -- only.
    -- @param skill_id [String ID of the skill]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
    --   'error.levels.no_active_character', 'error.levels.invalid_skill',
    --   'error.levels.no_skill_points', 'error.levels.skill_maxed' or
    --   'error.levels.cannot_raise']
    function player_meta:spend_skill_point(skill_id)
      return spend_point(self, skill_id, 'skill_points', skill_handlers, {
        invalid = 'error.levels.invalid_skill',
        empty = 'error.levels.no_skill_points',
        maxed = 'error.levels.skill_maxed'
      })
    end

    --- Spends one unspent attribute point of the player's character on a stat of the Stats
    -- plugin, raising it by one level. Refused when the stat is not registered or is hidden,
    -- the character has no attribute points left or the stat is at its highest level. Server
    -- only.
    -- @param stat_id [String attribute ID of the stat]
    -- @return [Boolean true if the point was spent, String phrase of the reason otherwise:
    --   'error.levels.no_active_character', 'error.levels.invalid_stat',
    --   'error.levels.no_attribute_points', 'error.levels.stat_maxed' or
    --   'error.levels.cannot_raise']
    function player_meta:spend_attribute_point(stat_id)
      return spend_point(self, stat_id, 'attribute_points', attribute_handlers, {
        invalid = 'error.levels.invalid_stat',
        empty = 'error.levels.no_attribute_points',
        maxed = 'error.levels.stat_maxed'
      })
    end
  end
end
