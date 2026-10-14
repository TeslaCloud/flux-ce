--- Rolls of the Stats plugin, on both realms. A roll is a twenty-sided die plus a modifier,
-- worked out by the `Dice` library: the modifier of a stat is its level, boosts included,
-- and the modifier of a skill is the level of its key stat (the `attribute` field of the
-- skill) plus the proficiency of the character in the skill. An untrained skill has no
-- proficiency; a trained one has its rank times the `stats_rank_bonus` config, plus the
-- level of the character from the Levels plugin, or 1 without it.
-- ```
-- -- Strength 2, athletics at rank 1 (trained), character level 3, rank bonus 2:
-- target:get_attribute_modifier('strength') -- 2
-- target:get_skill_modifier('athletics')    -- 2 + (1 * 2 + 3) = 7
-- target:roll_skill('athletics')            -- the result of '1d20 + 7'
-- ```
-- The AdjustAttributeRoll hook can change the formula of a roll before it is rolled, and
-- the result reports a natural 20 or 1 in its `critical` field.
--
-- This file is included before the attributes folder and before sh_plugin.lua, which is why
-- it makes the plugin available as the `Stats` global if no other file has done so yet.

local tonumber = tonumber
local math_floor = math.floor

if !Stats then
  PLUGIN:set_global('Stats')
end

Stats.default_rank_bonus = 2

--- Returns the proficiency that every rank of a trained skill adds to its rolls.
-- @return [Number the `stats_rank_bonus` config, 2 while it has no value]
function Stats:get_rank_bonus()
  local bonus = tonumber(Config.get('stats_rank_bonus'))

  if !bonus or bonus != bonus then
    return self.default_rank_bonus
  end

  return bonus
end

--- Returns the level of a character as rolls count it: the level from the Levels plugin,
-- or 1 while that plugin is not loaded.
-- @param target [Player]
-- @return [Number]
function Stats:get_character_level(target)
  if Levels and isfunction(target.get_level) then
    return tonumber(target:get_level()) or 1
  end

  return 1
end

--- Returns the kind of roll an attribute is rolled with.
-- @param attribute_table [AttributeBase]
-- @return [String 'attribute' for a stat, 'skill' for a skill; nil for any other attribute]
function Stats:get_roll_kind(attribute_table)
  if !istable(attribute_table) then return end

  if attribute_table.type == ATTRIBUTE_STAT then
    return 'attribute'
  elseif attribute_table.type == ATTRIBUTE_SKILL then
    return 'skill'
  end
end

--- Returns the proficiency of a player in a skill: 0 while the skill is untrained, else the
-- rank of the skill, boosts included, times the rank bonus, plus the level of the character.
-- @param target [Player]
-- @param skill_id [String ID of the skill]
-- @return [Number]
-- @see [Stats:get_rank_bonus]
-- @see [Stats:get_character_level]
function Stats:get_proficiency(target, skill_id)
  local rank = math_floor(target:get_attribute(skill_id))

  if rank <= 0 then
    return 0
  end

  return rank * self:get_rank_bonus() + self:get_character_level(target)
end

--- Builds the formula of a roll with a modifier: '1d20 + 3', '1d20 - 2', or '1d20' for a
-- modifier of 0.
-- @param modifier [Number]
-- @return [String]
function Stats:get_roll_formula(modifier)
  modifier = tonumber(modifier) or 0

  if modifier > 0 then
    return '1d20 + '..modifier
  elseif modifier < 0 then
    return '1d20 - '..math.abs(modifier)
  end

  return '1d20'
end

--- Finds the stat or the skill that a player has named, for example as the argument of a
-- command. The name may be the ID of the attribute, or its title or its short name (the
-- phrase `attribute.<id>.short`) in any language, in any case and with spaces or
-- underscores. An ID wins over a title or a short name.
-- ```
-- Stats:find_rollable('Close Combat') -- { id = 'close_combat', kind = 'skill' }
-- Stats:find_rollable('str')          -- { id = 'strength', kind = 'attribute' }
-- ```
-- @param name [String]
-- @return [Map id (String attribute ID) and kind ('attribute' or 'skill'); nil if no stat
--   or skill goes by that name]
function Stats:find_rollable(name)
  if !isstring(name) then return end

  local id = name:strip():to_id()

  if id == '' then return end

  local rollable = {}

  for k, v in pairs(Attributes.get_stored()) do
    local kind = self:get_roll_kind(v)

    if kind then
      if k == id then
        return { id = k, kind = kind }
      end

      rollable[k] = kind
    end
  end

  local languages = Flux.Lang:get_languages()

  for k, kind in pairs(rollable) do
    local attribute_table = Attributes.find(k)
    local short = 'attribute.'..k..'.short'

    for i = 1, #languages do
      local lang = languages[i]

      if t(attribute_table.name, nil, lang):to_id() == id or t(short, nil, lang):to_id() == id then
        return { id = k, kind = kind }
      end
    end
  end
end

--- Rolls a formula for a player after the AdjustAttributeRoll hook has had its say.
-- @param actor [Player player who rolls]
-- @param id [String ID of the stat or the skill]
-- @param kind [String 'attribute' or 'skill']
-- @param modifier [Number modifier of the roll]
-- @return [Map the Dice result, or nil and String the error of the Dice library]
local function roll(actor, id, kind, modifier)
  local roll_data = {
    id = id,
    kind = kind,
    modifier = modifier,
    formula = Stats:get_roll_formula(modifier)
  }

  --- Lets plugins change a roll of a stat or a skill before it is rolled, for example to
  -- add a situational bonus or to roll with advantage. Called in the realm that rolls,
  -- which is the server for the rolls that are shown in the chat, once for every call of
  -- `Player:roll_attribute` and `Player:roll_skill`. Every handler may change the table,
  -- so a handler should return nothing to let the others run.
  -- ```
  -- function PLUGIN:AdjustAttributeRoll(actor, roll_data)
  --   if roll_data.id == 'stealth' and actor:Crouching() then
  --     roll_data.formula = roll_data.formula..' + 2'
  --   end
  -- end
  -- ```
  -- @param actor [Player The player who rolls]
  -- @param roll_data [Map The roll, modified in place: id (String ID of the stat or the
  --   skill), kind (String 'attribute' or 'skill'), modifier (Number the modifier of the
  --   player) and formula (String the Dice formula that is rolled, '1d20 + modifier';
  --   change it to change the roll)]
  hook.Run('AdjustAttributeRoll', actor, roll_data)

  local formula = isstring(roll_data.formula) and roll_data.formula or Stats:get_roll_formula(modifier)

  return Dice.roll(formula)
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the modifier that an attribute adds to the player's rolls: its level, boosts
  -- included.
  -- @param stat_id [String ID of the stat]
  -- @return [Number 0 if the attribute is not registered]
  function player_meta:get_attribute_modifier(stat_id)
    if !Attributes.find(stat_id) then
      return 0
    end

    local level = self:get_attribute(stat_id)

    return level
  end

  --- Returns the modifier that a skill adds to the player's rolls: the modifier of the key
  -- stat of the skill plus the player's proficiency in it.
  -- @param skill_id [String ID of the skill]
  -- @return [Number 0 if the skill is not registered]
  -- @see [Stats:get_proficiency]
  function player_meta:get_skill_modifier(skill_id)
    local skill = Attributes.find(skill_id)

    if !skill or skill.type != ATTRIBUTE_SKILL then
      return 0
    end

    local modifier = Stats:get_proficiency(self, skill_id)

    if isstring(skill.attribute) then
      modifier = modifier + self:get_attribute_modifier(skill.attribute)
    end

    return modifier
  end

  --- Rolls a stat for the player: a d20 plus the modifier of the stat, after the
  -- AdjustAttributeRoll hook.
  -- ```
  -- local result = target:roll_attribute('strength')
  --
  -- if result and result.total >= 15 then
  --   door:Fire('Unlock')
  -- end
  -- ```
  -- @param stat_id [String ID of the stat]
  -- @return [Map the result of `Dice.roll`, or nil and String the reason if nothing was
  --   rolled]
  function player_meta:roll_attribute(stat_id)
    local attribute_table = Attributes.find(stat_id)

    if Stats:get_roll_kind(attribute_table) != 'attribute' then
      return nil, t('error.stats.not_stat', { name = tostring(stat_id) })
    end

    return roll(self, stat_id, 'attribute', self:get_attribute_modifier(stat_id))
  end

  --- Rolls a skill for the player: a d20 plus the modifier of the skill, after the
  -- AdjustAttributeRoll hook.
  -- @param skill_id [String ID of the skill]
  -- @return [Map the result of `Dice.roll`, or nil and String the reason if nothing was
  --   rolled]
  -- @see [Player#get_skill_modifier]
  function player_meta:roll_skill(skill_id)
    local attribute_table = Attributes.find(skill_id)

    if Stats:get_roll_kind(attribute_table) != 'skill' then
      return nil, t('error.stats.not_skill', { name = tostring(skill_id) })
    end

    return roll(self, skill_id, 'skill', self:get_skill_modifier(skill_id))
  end
end
