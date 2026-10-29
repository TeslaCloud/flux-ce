--- Registry of the skill definitions. The player methods that read and change the skills of a
-- player's character are in `lib/meta`.
-- Definitions are `SkillBase` objects registered with `Skills.register`, usually by
-- `Skills.include_skills` loading the files of a plugin's `skills` folder. This file adds
-- `skills` to the extra folders of every plugin and handles that folder through the
-- PluginIncludeFolder hook. It is part of the lib folder of the Stats plugin, which Flux
-- includes before the other folders of the plugin and before its sh_plugin.lua, so the skills
-- folder of the Stats plugin is loaded this way too, as are those of the plugins and the
-- schema that load after it. `SkillBase` is defined by lib/classes/sh_skill.lua, which Flux
-- includes after this file but before the skills folder of any plugin.
--
-- What a character has of a skill is kept in a `Skill` record: its rank, from 0 to the `max`
-- of the skill. A rank changes only when it is set, by staff or by the code of a plugin, such
-- as the Levels plugin spending a point on it. The server networks the skills of a player to
-- that player alone, in the private 'skills' networked variable, which the getters read on
-- the client.

mod 'Skills'

local istable = istable
local tonumber = tonumber
local math_clamp = math.clamp
local math_round = math.round

local stored = Skills.stored or {}
Skills.stored = stored

--- Returns every registered skill definition.
-- @return [Map skill definitions keyed by skill ID]
function Skills.get_stored()
  return stored
end

--- Returns the definition of a registered skill.
-- @param id [String skill ID]
-- @return [SkillBase the skill definition, or nil if it is not registered]
function Skills.find(id)
  return stored[id]
end

--- Stores a skill definition and runs the SkillRegistered hook. Missing fields get defaults:
-- the name 'skill.other.name', the description 'skill.other.desc' and a `max` of 4. The `max`
-- is rounded down and is never below 1.
-- ```
-- local skill = SkillBase.new('lockpicking')
-- skill.name = 'skill.lockpicking.title'
-- skill.attribute = 'reflexes'
--
-- Skills.register(skill.skill_id, skill)
-- ```
-- @param id [String unique skill ID; raises an error when it is not a string]
-- @param data [SkillBase skill definition; nothing happens when it is nil]
-- @see [SkillBase#register]
function Skills.register(id, data)
  if !data then return end

  if !isstring(id) then
    error_with_traceback('Attempt to register a skill without a valid ID!')

    return
  end

  data.name = data.name or 'skill.other.name'
  data.description = data.description or 'skill.other.desc'
  data.max = math.max(math.floor(tonumber(data.max) or 4), 1)

  --- Called on both realms when a skill definition is registered, after its missing fields
  -- have been given their defaults and before it is stored. A handler may change the
  -- definition.
  -- @param id [String Skill ID]
  -- @param data [SkillBase The skill definition]
  hook.Run('SkillRegistered', id, data)

  stored[id] = data
end

--- Includes every file of a folder as a skill definition. Each file gets a fresh SKILL global,
-- a SkillBase named after the file, that is registered once the file has run.
-- ```
-- -- skills/sh_athletics.lua, registered as 'athletics'
-- SKILL.name = 'skill.athletics.title'
-- SKILL.attribute = 'strength'
-- ```
-- @param directory [String folder to include files from]
function Skills.include_skills(directory)
  Pipeline.include_folder('skill', directory)
end

--- Checks whether a skill is shown to a player on the character sheet. A skill with its
-- hidden field set is never shown; any other can be hidden with the ShouldShowSkill hook.
-- @param skill [SkillBase skill definition]
-- @param target [Player player whose skills are being shown]
-- @return [Boolean]
function Skills.is_visible(skill, target)
  if !skill or skill.hidden then return false end

  --- Lets plugins hide a skill from a player, for example one that the faction of the player
  -- has no use for. Called on the client for every registered skill that does not have its
  -- hidden field set, when the tab menu is opened and twice a second while the character
  -- sheet is open, so that the sheet follows a changed answer.
  -- @param target [Player The player whose skills are being shown, the local player]
  -- @param skill [SkillBase The skill definition]
  -- @return [Boolean Return false to hide the skill]
  return hook.Run('ShouldShowSkill', target, skill) != false
end

if SERVER then
  --- Returns the active character of a player, if they have one.
  -- @param target [Player]
  -- @return [Character/Map the character record, or the stand-in table of a bot; nil if the
  --   player is not valid or has no active character]
  local function get_character(target)
    if !IsValid(target) or !target:is_character_loaded() then return end

    return target:get_character()
  end

  local function get_records(target)
    local character = get_character(target)

    return istable(character) and istable(character.skills) and character.skills or {}
  end

  --- Finds the record that a character keeps for a skill.
  -- @param character [Character character record; anything else finds nothing]
  -- @param skill_id [String]
  -- @return [Skill the record, or nil if the character has none]
  function Skills.get_record(character, skill_id)
    if !istable(character) or !istable(character.skills) then return end

    for _, record in ipairs(character.skills) do
      if record.skill_id == skill_id then
        return record
      end
    end
  end

  --- Gives a character a record for every registered skill it has none for. A new record
  -- starts at the given rank, rounded down and kept between 0 and the skill's max, or at
  -- rank 0. The records are saved with the character.
  -- @param character [Character]
  -- @param ranks=nil [Map starting ranks keyed by skill ID]
  -- @return [Number amount of records added]
  function Skills.create_records(character, ranks)
    if !istable(character) or !istable(character.skills) then return 0 end

    ranks = istable(ranks) and ranks or {}

    local added = 0

    for skill_id, skill_table in pairs(stored) do
      if !Skills.get_record(character, skill_id) then
        local rank = tonumber(ranks[skill_id])

        if !rank or rank != rank then
          rank = 0
        end

        local skill = Skill.new()
          skill.skill_id = skill_id
          skill.rank = math_clamp(math.floor(rank), 0, skill_table.max)
        table.insert(character.skills, skill)

        added += 1
      end
    end

    return added
  end

  --- Builds the table that is networked for a player: the rank of every registered skill
  -- their character has a record for.
  -- @param target [Player]
  -- @return [Map ranks keyed by skill ID]
  function Skills.to_networkable(target)
    local skills = {}

    for _, record in ipairs(get_records(target)) do
      if stored[record.skill_id] then
        skills[record.skill_id] = tonumber(record.rank) or 0
      end
    end

    return skills
  end

  --- Networks the skills of a player's character to that player again. Called after every
  -- change the plugin makes; call it yourself after changing the records directly.
  -- @param target [Player]
  function Skills.sync(target)
    if !IsValid(target) then return end

    target:set_private_nv('skills', Skills.to_networkable(target))
  end

  --- Sets the rank of a skill of a player's character, networks the skills and runs the
  -- PlayerSkillChanged hook. Nothing happens if the rank does not change or the character has
  -- no record for the skill.
  -- @param target [Player]
  -- @param skill_id [String]
  -- @param rank [Number new rank, rounded and kept between 0 and the skill's max]
  -- @return [Boolean true if the rank has changed]
  function Skills.update(target, skill_id, rank)
    local skill = stored[skill_id]
    local record = skill and Skills.get_record(get_character(target), skill_id)

    if !record then return false end

    local old_rank = tonumber(record.rank) or 0

    rank = tonumber(rank)

    if !rank or rank != rank then return false end

    rank = math_clamp(math_round(rank), 0, skill.max)

    if rank == old_rank then return false end

    record.rank = rank

    Skills.sync(target)

    --- Called on the server after the rank of a skill of a player's character has changed
    -- and the change has been networked, however it came about: through `Player:set_skill`
    -- and the methods built on it, the CharSetSkill command or the points the Levels plugin
    -- lets players spend.
    -- @param actor [Player The player whose character the skill belongs to]
    -- @param skill_id [String Skill ID]
    -- @param rank [Number New rank]
    -- @param old_rank [Number Rank before the change]
    hook.Run('PlayerSkillChanged', target, skill_id, rank, old_rank)

    return true
  end
end

Pipeline.register('skill', function(id, file_name, _pipe)
  SKILL = SkillBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then SKILL = nil return end

  SKILL:register()
  SKILL = nil
end)

--- Hook handlers of the skill registry, registered as `Skills` while this file is included,
-- before the Stats plugin itself is registered, so that they already handle the folders of
-- the Stats plugin. The handlers registered under that ID by an earlier inclusion of the file
-- are removed first, so they are never registered twice.
local hooks = {}

--- Includes a plugin's skills folder when the 'skills' extra is being loaded.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function hooks:PluginIncludeFolder(extra, folder)
  if extra == 'skills' then
    Skills.include_skills(folder..'/skills')

    return true
  end
end

Plugin.remove_hooks('Skills')
Plugin.add_hooks('Skills', hooks)
Plugin.add_extra('skills')
