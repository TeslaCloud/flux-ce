--- Player extensions of the Levels plugin: the level, the experience and the unspent skill
-- and attribute points of the character of a player.

local istable = istable
local tonumber = tonumber
local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max
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
