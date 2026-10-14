--- Definition of a skill: its name, description and icon, the ID of the attribute it relies
-- on (`attribute`, its key stat), its highest rank (`max`) and the `hidden` flag.
-- A file in a plugin's `skills` folder fills in a `SkillBase` through the `SKILL` global;
-- `Skills.register` supplies the defaults of the missing fields.
--
-- The rank of a skill goes from 0 to `max`, and a character starts every skill at rank 0.
-- The level of the key stat is added to every roll of the skill, and the character sheet
-- lists the skill under it.
--
-- A skill can name its ranks. `ranks` is a map of rank IDs to the phrases that describe what
-- that rank of the skill means, `rank_order` lists the rank IDs from rank 0 upwards, and
-- `rank_names` optionally maps a rank ID to the phrase of its name, which is
-- `skill.rank.<id>` otherwise. The default `rank_order` goes from 'untrained' through
-- 'trained', 'expert' and 'master' to 'legendary', which fits a skill with a `max` of 4.
-- ```
-- -- skills/sh_athletics.lua
-- SKILL.name = 'skill.athletics.title'
-- SKILL.description = 'skill.athletics.description'
-- SKILL.icon = 'fa-person-running'
-- SKILL.attribute = 'strength'
-- SKILL.max = 4
-- SKILL.ranks = {
--   untrained = 'skill.athletics.untrained',
--   trained = 'skill.athletics.trained',
--   expert = 'skill.athletics.expert',
--   master = 'skill.athletics.master',
--   legendary = 'skill.athletics.legendary'
-- }
-- ```

class 'SkillBase'

SkillBase.rank_order = { 'untrained', 'trained', 'expert', 'master', 'legendary' }

--- Creates a skill definition. Fill in its fields and call register to make it available.
-- ```
-- local skill = SkillBase.new('lockpicking')
-- skill.name = 'skill.lockpicking.title'
-- skill.description = 'skill.lockpicking.description'
-- skill.attribute = 'reflexes'
-- skill:register()
-- ```
-- @param id [String unique skill ID; nothing is set when it is not a string]
function SkillBase:init(id)
  if !isstring(id) then return end

  self.skill_id = id
end

--- Returns the ID of the named rank that a rank of this skill falls on: the entry of
-- `rank_order` at the position of the rank counted from 0. A rank beyond either end of the
-- list takes the first or the last entry.
-- @param rank [Number]
-- @return [String rank ID, or nil if the skill does not name its ranks or `ranks` has no
--   entry for that rank]
function SkillBase:get_rank_id(rank)
  local order = self.rank_order

  if !istable(self.ranks) or !istable(order) or #order == 0 or !isnumber(rank) then return end

  local id = order[math.clamp(math.floor(rank) + 1, 1, #order)]

  if self.ranks[id] != nil then
    return id
  end
end

--- Returns the phrase that names a rank of this skill, such as 'skill.rank.expert'.
-- @param rank [Number]
-- @return [String phrase, or nil if the skill does not name that rank]
-- @see [SkillBase#get_rank_id]
function SkillBase:get_rank_name(rank)
  local id = self:get_rank_id(rank)

  if !id then return end

  local names = self.rank_names

  return istable(names) and names[id] or 'skill.rank.'..id
end

--- Returns the phrase that describes a rank of this skill, taken from `ranks`.
-- @param rank [Number]
-- @return [String phrase, or nil if the skill does not describe that rank]
-- @see [SkillBase#get_rank_id]
function SkillBase:get_rank_description(rank)
  local id = self:get_rank_id(rank)
  local description = id and self.ranks[id]

  if isstring(description) then
    return description
  end
end

--- Registers this skill definition under its skill ID.
-- @see [Skills.register]
function SkillBase:register()
  return Skills.register(self.skill_id, self)
end
