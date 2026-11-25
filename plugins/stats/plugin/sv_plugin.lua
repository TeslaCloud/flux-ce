--- Server side of the Stats plugin: the stat bonuses of factions, the rolls that are shown to
-- the players nearby and the effects of stats that hand out whole points.
-- The 'fl_attributes_view' message, which the `attribute list` command sends to show a
-- character's attributes and skills to a member of staff, is registered here; it carries the
-- player, their attributes as `Player:get_attributes` returns them and their skills as
-- `Player:get_skills` returns them. So is the 'fl_stats_roll_result' message, the answer to
-- 'fl_stats_roll' that lets the character sheet show the result on the button that was
-- pressed; it carries the ID of the stat or the skill and the result (a Map with the formula,
-- total, natural, critical and rolls fields of the `Dice` result), or nil when nothing was
-- rolled.

local IsValid = IsValid
local math_max = math.max

Cable.check_networked_string('fl_attributes_view')
Cable.check_networked_string('fl_stats_roll_result')

--- Multiplies an amount that is handed out in whole points, keeping the fraction that gets
-- cut off for the next call. Over time the player receives exactly the scaled amount, which
-- rounding every call by itself would not give for small amounts.
-- @param target [Player player the amount is for; the fraction is kept on them]
-- @param id [String name of what is being handed out, the fractions are kept apart by it]
-- @param amount [Number amount before scaling]
-- @param scale [Number multiplier]
-- @return [Number whole amount to hand out now, 0 or more]
function Stats:scale_whole(target, id, amount, scale)
  local carry = target.stat_effect_carry or {}
  local scaled = amount * scale + (carry[id] or 0)
  local whole = math_max(math.floor(scaled), 0)

  carry[id] = math_max(scaled - whole, 0)
  target.stat_effect_carry = carry

  return whole
end

--- Gives a player the stat bonuses of their faction and takes away the ones that their
-- faction does not give: every bonus is a boost without expiry that carries the
-- `Stats.faction_boost_id` identifier. Boosts that are right already are left alone, so
-- loading a character does not rewrite them. Without the Factions plugin, or with the
-- bonuses turned off, all of them are removed.
-- @param target [Player]
-- @return [Number amount of stats whose bonus was added, replaced or removed]
function Stats:apply_faction_bonuses(target)
  if !IsValid(target) or !target:is_character_loaded() then
    return 0
  end

  local enabled = self:faction_bonuses_enabled()

  local bonuses = {}

  if enabled and Factions then
    bonuses = self:get_faction_bonuses(target:get_faction())
  end

  local changed = 0

  for stat_id in pairs(Attributes.get_stored()) do
    local wanted, current = bonuses[stat_id], self:get_faction_boost(target, stat_id)

    if wanted and wanted != current then
      if target:boost_attribute(stat_id, wanted, nil, self.faction_boost_id) then
        changed += 1
      end
    elseif !wanted and current then
      if target:remove_attribute_boost(stat_id, self.faction_boost_id) then
        changed += 1
      end
    end
  end

  return changed
end

--- Rolls an attribute or a skill of a player and shows the result to the players nearby, the way
-- the `roll` command of the RolePlay Commands plugin shows a roll. Without that plugin the
-- result is shown to the player alone, as a notification. A roll that fails, such as one
-- whose formula a handler of the AdjustAttributeRoll hook has broken, is reported to the
-- player.
-- @param actor [Player player who rolls]
-- @param id [String ID of an attribute or a skill; an attribute wins over a skill with the
--   same ID]
-- @return [Map the Dice result, or nil and String the reason if nothing was rolled]
-- @see [Player#roll_attribute]
-- @see [Player#roll_skill]
function Stats:roll_and_announce(actor, id)
  local definition = Attributes.find(id)
  local result, err

  if definition then
    result, err = actor:roll_attribute(id)
  else
    definition = Skills.find(id)

    if !definition then
      return nil, t('error.stats.unknown_rollable', { name = tostring(id) })
    end

    result, err = actor:roll_skill(id)
  end

  if !result then
    actor:notify('error.stats.roll', { name = definition.name, message = tostring(err) })

    return nil, err
  end

  if RPCommands and isfunction(RPCommands.announce_roll) then
    RPCommands:announce_roll(actor, result, nil, nil, t(definition.name))
  else
    actor:notify('notification.stats.roll', { name = definition.name, roll = self:format_roll(result) })
  end

  return result
end
