--- Shared helpers of the Stats plugin for what the stats of a character do in play.
-- An effect of a stat changes some value by a fixed share for every level of the stat: a
-- percentage of the value, read from one of the `stats_` config keys, or a distance in
-- meters. Levels above zero help the character, levels below zero hinder it, and a config
-- of 0 turns the effect off. The server side hook handlers of the plugin ask
-- `Stats:get_player_effect_scale` for the multiplier to apply, and the files of the
-- attributes folder build the entries of their `effects` list with `Stats:percent_effect`
-- and `Stats:distance_effect`, so that what the creation stage and the Attributes tab show
-- is worked out the same way as what the server applies.
--
-- This file is included before the attributes folder and before sh_plugin.lua, which is why
-- it is the one that makes the plugin available as the `Stats` global.

local tonumber = tonumber
local config_get = Config.get
local math_max = math.max
local math_round = math.Round
local positive_color = Color('lightgreen')
local negative_color = Color('pink')

if !Stats then
  PLUGIN:set_global('Stats')
end

Stats.min_effect_scale = 0.1

--- Returns the share of a value that one level of a stat changes, from the config of an
-- effect.
-- @param key [String config key of the effect, a percentage per level]
-- @return [Number share per level, 0.1 for a config of 10; 0 while the config has no value]
function Stats:get_effect_rate(key)
  local percent = tonumber(config_get(key))

  if !percent or percent != percent then
    return 0
  end

  return percent * 0.01
end

--- Returns the multiplier that a level of a stat gives to the value an effect is about.
-- The multiplier never falls below `Stats.min_effect_scale`, whatever boosts add to the
-- level.
-- ```
-- -- With the 'stats_strength_lifting' config at 10:
-- Stats:get_effect_scale(2, 'stats_strength_lifting')       -- 1.2
-- Stats:get_effect_scale(-3, 'stats_strength_lifting')      -- 0.7
-- Stats:get_effect_scale(2, 'stats_strength_lifting', true) -- 0.8
-- ```
-- @param level [Number level of the stat, boosts included]
-- @param key [String config key of the effect, a percentage per level]
-- @param inverse=false [Boolean the stat lowers the value instead of raising it]
-- @return [Number multiplier, 1 when the level or the config is 0]
function Stats:get_effect_scale(level, key, inverse)
  local change = (tonumber(level) or 0) * self:get_effect_rate(key)

  if inverse then
    change = -change
  end

  return math_max(1 + change, self.min_effect_scale)
end

--- Returns the multiplier that the level of a player in a stat, boosts included, gives to
-- the value an effect is about.
-- @param target [Player]
-- @param attribute_id [String ID of the stat]
-- @param key [String config key of the effect, a percentage per level]
-- @param inverse=false [Boolean the stat lowers the value instead of raising it]
-- @return [Number multiplier, 1 when the stat has no effect on the player]
-- @see [Stats:get_effect_scale]
function Stats:get_player_effect_scale(target, attribute_id, key, inverse)
  local level = target:get_attribute(attribute_id)

  return self:get_effect_scale(level, key, inverse)
end

--- Formats a change as text with its sign in front: '+10%', '-1.5m' or '0%'.
-- @param amount [Number the change]
-- @param suffix='' [String text to put right after the number, such as '%']
-- @return [String]
function Stats:format_change(amount, suffix)
  local sign = ''

  if amount > 0 then
    sign = '+'
  elseif amount < 0 then
    sign = '-'
  end

  return sign..math.abs(amount)..(suffix or '')
end

--- Returns the color to show a change in: green for one that helps the character, pink for
-- one that hinders it and white for none.
-- @param change [Number the change]
-- @param inverse=false [Boolean a lower value is the better one]
-- @return [Color]
function Stats:get_change_color(change, inverse)
  if change == 0 then
    return color_white
  end

  if (change > 0) != (inverse == true) then
    return positive_color
  end

  return negative_color
end

--- Builds an entry of the `effects` list of a stat for an effect that changes a value by a
-- percentage per level. The entry has what the creation stage and the Attributes tab read
-- (`text`, `get_value` and `get_color`, the last two taking a level), plus `is_active`,
-- which tells whether the effect does anything at the moment, and `get_change`, which
-- returns the change at a level in percent. An effect that is not active shows as '0%'.
-- ```
-- ATTRIBUTE.effects = {
--   Stats:percent_effect('ui.effect.stamina_drain', 'stats_endurance_stamina', true, function()
--     return Stamina != nil
--   end)
-- }
-- ```
-- @param text [String phrase that names the value]
-- @param key [String config key of the effect, a percentage per level]
-- @param inverse=false [Boolean the stat lowers the value instead of raising it]
-- @param is_available=nil [Function called without arguments; a false or nil result means
--   that what the effect relies on, such as another plugin, is missing]
-- @return [Map entry for the effects list]
function Stats:percent_effect(text, key, inverse, is_available)
  local effect = {
    text = text,
    config = key,
    inverse = inverse == true
  }

  effect.is_active = function()
    if self:get_effect_rate(key) == 0 then
      return false
    end

    if is_available and !is_available() then
      return false
    end

    return true
  end

  effect.get_change = function(level)
    if !effect.is_active() then
      return 0
    end

    return math_round((self:get_effect_scale(level, key, effect.inverse) - 1) * 100, 1)
  end

  effect.get_value = function(level)
    return self:format_change(effect.get_change(level), '%')
  end

  effect.get_color = function(level)
    return self:get_change_color(effect.get_change(level), effect.inverse)
  end

  return effect
end

--- Builds an entry of the `effects` list of a stat for an effect that adds a distance per
-- level. The entry has the same fields as the one of `Stats:percent_effect`; its
-- `get_change` returns meters.
-- @param text [String phrase that names the distance]
-- @param key [String config key of the effect, meters per level]
-- @return [Map entry for the effects list]
-- @see [Stats:percent_effect]
function Stats:distance_effect(text, key)
  local effect = {
    text = text,
    config = key,
    inverse = false
  }

  effect.is_active = function()
    return (tonumber(config_get(key)) or 0) != 0
  end

  effect.get_change = function(level)
    return math_round((tonumber(level) or 0) * (tonumber(config_get(key)) or 0), 1)
  end

  effect.get_value = function(level)
    local unit = t'ui.unit.m'

    return self:format_change(effect.get_change(level), unit)
  end

  effect.get_color = function(level)
    return self:get_change_color(effect.get_change(level))
  end

  return effect
end
