--- Server side of the Stats plugin: gives characters their attribute and skill records,
-- networks a character's attributes and skills when it becomes active and removes its boosts
-- as they expire, checks the stats of new characters, keeps the stat bonuses of the faction
-- on every character, applies the effects of the stats through the hooks of the Chatbox,
-- Stamina, Pickup Objects, Damage, Limb Damage and Vendors plugins, and rolls the attributes
-- and skills that a player asks for with the 'fl_stats_roll' message. A handler of a plugin
-- that is not loaded is never called. The 'fl_attributes_view' message, which the
-- `attribute list` command sends to show a character's attributes and skills to a member of
-- staff, is registered here; it carries the player, their attributes as
-- `Player:get_attributes` returns them and their skills as `Player:get_skills` returns them.
-- So is the 'fl_stats_roll_result' message, the answer to 'fl_stats_roll' that lets the
-- character sheet show the result on the button that was pressed; it carries the ID of the
-- stat or the skill and the result (a Map with the formula, total, natural, critical and
-- rolls fields of the `Dice` result), or nil when nothing was rolled.

local IsValid = IsValid
local isnumber = isnumber
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
local function scale_whole(target, id, amount, scale)
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
-- @param enabled=nil [Boolean whether bonuses are given; the `stats_faction_bonuses` config
--   when nil]
-- @return [Number amount of stats whose bonus was added, replaced or removed]
function Stats:apply_faction_bonuses(target, enabled)
  if !IsValid(target) or !target:is_character_loaded() then
    return 0
  end

  if enabled == nil then
    enabled = self:faction_bonuses_enabled()
  end

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

--- Adds an Attribute record for every registered attribute to a new character, using the
-- level chosen during creation or the attribute's default, and a Skill record at rank 0 for
-- every registered skill. A chosen level is rounded down and kept between the attribute's
-- min and max, as the creation data comes from the client.
-- @param _owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data; levels are read from its attributes field]
function Stats:PostCreateCharacter(_owner, char, char_data)
  Attributes.create_records(char, char_data.attributes)
  Skills.create_records(char)
end

--- Prepares the attributes and skills of the character that has become active: adds
-- records for the attributes and skills that were registered after the character was
-- created, removes the boosts that have expired or whose expiry time cannot be read,
-- networks the attributes and skills to the player and gives the character the stat bonuses
-- of its faction.
-- @param owner [Player]
-- @param character [Character the character that is now active]
function Stats:OnActiveCharacterSet(owner, character)
  Attributes.create_records(character)
  Attributes.remove_expired(owner)
  Attributes.sync(owner)
  Skills.create_records(character)
  Skills.sync(owner)

  self:apply_faction_bonuses(owner)
end

--- Takes the networked attributes and skills of a character away from the player who drops
-- it, and forgets when its next boost expires and the fractions of effects carried over.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Stats:OnActiveCharacterCleared(owner, _character)
  owner.attribute_expiry = nil
  owner.stat_effect_carry = nil

  owner:set_private_nv('attributes', {})
  owner:set_private_nv('skills', {})
end

--- Removes the boosts that have expired from the characters of the players who have one
-- due, and networks their attributes again so that the clients stop counting them when the
-- server does.
function Stats:OneSecond()
  local unix_time = os.time()

  for _, client in player.Iterator() do
    local expiry = client.attribute_expiry

    if expiry and expiry <= unix_time then
      Attributes.remove_expired(client)
      Attributes.sync(client)
    end
  end
end

--- Replaces the stat bonuses of a player who has been moved to another faction.
-- @param target [Player]
-- @param _faction_table [Faction the faction the player is in now]
-- @param _old_faction [Faction the faction the player was in before, or nil]
function Stats:OnPlayerFactionChanged(target, _faction_table, _old_faction)
  self:apply_faction_bonuses(target)
end

--- Gives or takes the faction bonuses of everyone online when the `stats_faction_bonuses`
-- config changes. The hook runs before the new value is stored, so the value is passed on.
-- @param key [String config key]
-- @param old_value [Any]
-- @param new_value [Any]
function Stats:OnConfigSet(key, old_value, new_value)
  if key != 'stats_faction_bonuses' or old_value == new_value then return end

  for _, client in player.Iterator() do
    self:apply_faction_bonuses(client, new_value != false)
  end
end

--- Extends the hearing radius of in character messages by the `stats_perception_hearing`
-- config, 1.5 meters by default, for every level of the listener's perception, and shortens
-- it for every level below zero.
-- Only a message that has a hearing range is changed. The Chatbox plugin sends a message
-- with a radius of 0 to everyone and one with a negative radius to nobody but the players
-- that the PlayerCanHear hook lets through, which is how a radio transmission that is not
-- overheard is sent, so those radii are left alone. For the same reason a shortened radius
-- never falls below `Stats.min_hearing_radius`: at 0 the message would reach everyone.
-- @param listener [Player player hearing the message]
-- @param message_data [Map chat message data]
function Stats:AdjustMessageData(listener, message_data)
  local radius = message_data.radius

  if !message_data.ic or !isnumber(radius) or radius <= 0 then return end

  local meters = tonumber(Config.get('stats_perception_hearing')) or 0

  if meters == 0 then return end

  local level = listener:get_attribute('perception')

  if level == 0 then return end

  message_data.radius = math_max(radius + Unit:meter(level * meters), self.min_hearing_radius)
end

--- Rejects new characters unless each stat has a whole level between its minimum and its
-- creation limit and the levels add up to the points a new character gets.
-- @param _actor [Player player creating the character]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_ATTRIBUTE_SUM if the stat levels are not valid, nil otherwise]
-- @see [Stats:default_attribute_points]
-- @see [Stats:get_creation_max]
function Stats:PlayerCreateCharacter(_actor, data)
  local levels = data.attributes

  if !istable(levels) then
    return CHAR_ERR_ATTRIBUTE_SUM
  end

  local stats = Attributes.get_stored()
  local sum = 0

  for stat_id in pairs(levels) do
    if !stats[stat_id] then
      return CHAR_ERR_ATTRIBUTE_SUM
    end
  end

  for stat_id, stat in pairs(stats) do
    local level = levels[stat_id]

    if !isnumber(level) or level != math.floor(level) or level < stat.min or level > self:get_creation_max(stat) then
      return CHAR_ERR_ATTRIBUTE_SUM
    end

    sum += level
  end

  if sum != self:default_attribute_points() then
    return CHAR_ERR_ATTRIBUTE_SUM
  end
end

--- Makes the stamina of a running player drain slower by the `stats_endurance_stamina`
-- config for every level of their endurance, and faster for every level below zero.
-- The Stamina plugin takes the first multiplier a plugin returns, so nothing is returned
-- for a player whose endurance changes nothing.
-- @param target [Player player who is running]
-- @return [Number multiplier of the drain rate, nil to leave it alone]
function Stats:StaminaAdjustDrainScale(target)
  local scale = self:get_player_effect_scale(target, 'endurance', 'stats_endurance_stamina', true)

  if scale != 1 then
    return scale
  end
end

--- Makes the stamina of a player regenerate faster by the `stats_endurance_stamina` config
-- for every level of their endurance, and slower for every level below zero.
-- @param target [Player player who is recovering]
-- @return [Number multiplier of the regeneration rate, nil to leave it alone]
function Stats:StaminaAdjustRegenScale(target)
  local scale = self:get_player_effect_scale(target, 'endurance', 'stats_endurance_stamina')

  if scale != 1 then
    return scale
  end
end

--- Raises the mass of the heaviest object a player can pick up by the
-- `stats_strength_lifting` config for every level of their strength, and lowers it for
-- every level below zero.
-- @param actor [Player player picking the object up]
-- @param _ent [Entity the object, or nil]
-- @param info [Map modified in place: limit (Number the mass limit)]
function Stats:AdjustPickupMassLimit(actor, _ent, info)
  if !IsValid(actor) or !actor:IsPlayer() or !isnumber(info.limit) then return end

  info.limit *= self:get_player_effect_scale(actor, 'strength', 'stats_strength_lifting')
end

--- Makes a player throw the object they hold harder by the `stats_strength_lifting` config
-- for every level of their strength, and weaker for every level below zero.
-- @param actor [Player player throwing the object]
-- @param _ent [Entity the object being thrown]
-- @param info [Map modified in place: force (Number the force of the throw)]
function Stats:PlayerThrowObject(actor, _ent, info)
  if !IsValid(actor) or !actor:IsPlayer() or !isnumber(info.force) then return end

  info.force *= self:get_player_effect_scale(actor, 'strength', 'stats_strength_lifting')
end

--- Lowers the fall damage a player takes by the `stats_reflexes_fall` config for every
-- level of their reflexes, and raises it for every level below zero.
-- @param victim [Player player about to take the damage]
-- @param damage_info [CTakeDamageInfo the damage, scaled in place]
-- @param _hitgroup [Number HITGROUP_ enum of the hit location]
function Stats:PrePlayerTakeDamage(victim, damage_info, _hitgroup)
  if !damage_info:IsFallDamage() then return end

  local scale = self:get_player_effect_scale(victim, 'reflexes', 'stats_reflexes_fall', true)

  if scale != 1 then
    damage_info:ScaleDamage(scale)
  end
end

--- Raises the health a player regenerates at once by the `stats_endurance_recovery` config
-- for every level of their endurance, and lowers it for every level below zero. Health
-- comes in whole points, so the fraction that does not fit is kept for the next time.
-- Returning an amount keeps the handlers of the schema and of the plugins loaded later from
-- being asked, so nothing is returned for a player whose endurance changes nothing.
-- @param target [Player player about to be healed]
-- @param amount [Number health the player would gain]
-- @return [Number health to give instead, nil to keep the amount]
function Stats:GetHealthRegeneration(target, amount)
  if !isnumber(amount) or amount <= 0 then return end

  local scale = self:get_player_effect_scale(target, 'endurance', 'stats_endurance_recovery')

  if scale != 1 then
    return scale_whole(target, 'health', amount, scale)
  end
end

--- Raises what the hurt limbs of a player recover in a minute by the
-- `stats_endurance_recovery` config for every level of their endurance, and lowers it for
-- every level below zero. Limbs recover in whole points, so the fraction that does not fit
-- is kept for the next minute. Nothing is returned for a player whose endurance changes
-- nothing, which leaves the answer to other handlers.
-- @param actor [Player player whose limbs are about to recover]
-- @param amount [Number damage that is about to be taken off each hurt limb]
-- @return [Number amount to take off instead, nil to keep it]
function Stats:GetLimbRecovery(actor, amount)
  if !isnumber(amount) or amount <= 0 then return end

  local scale = self:get_player_effect_scale(actor, 'endurance', 'stats_endurance_recovery')

  if scale != 1 then
    return scale_whole(actor, 'limbs', amount, scale)
  end
end

--- Lowers what a vendor asks of a customer by the `stats_charisma_prices` config for
-- every level of the customer's charisma, and raises it for every level below zero.
-- A lowered price never falls below what the same vendor pays for the item, so that an
-- item cannot be bought and sold back at a profit. What a vendor pays is left alone.
-- @param actor [Player the customer, or nil when a price is asked for without one]
-- @param vendor [Entity the vendor]
-- @param item_obj [Item template of the item the vendor sells]
-- @param price_info [Map modified in place: price (Number), selling (Boolean true if the
--   vendor sells the item)]
function Stats:AdjustVendorPrice(actor, vendor, item_obj, price_info)
  if !price_info.selling or !isnumber(price_info.price) then return end
  if !IsValid(actor) or !actor:IsPlayer() then return end

  local scale = self:get_player_effect_scale(actor, 'charisma', 'stats_charisma_prices', true)

  if scale == 1 then return end

  local price = price_info.price * scale

  if scale < 1 then
    local buy_price = Vendors:get_buy_price(vendor, item_obj, actor)

    if buy_price then
      price = math_max(price, math.min(buy_price, price_info.price))
    end
  end

  price_info.price = price
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

--- Picks the fields of a roll result that the character sheet needs to show it, leaving out
-- anything a handler of the AdjustAttributeRoll hook may have hung on the result.
-- @param result [Map result of `Dice.roll`]
-- @return [Map formula, total, natural, critical and rolls]
local function roll_summary(result)
  local rolls = {}

  for i, roll in ipairs(istable(result.rolls) and result.rolls or {}) do
    rolls[i] = {
      sides = roll.sides,
      results = roll.results,
      kept = roll.kept,
      dropped = roll.dropped,
      total = roll.total
    }
  end

  return {
    formula = result.formula,
    total = result.total,
    natural = result.natural,
    critical = result.critical,
    rolls = rolls
  }
end

Cable.receive('fl_stats_roll', function(actor, id)
  if !IsValid(actor) or !isstring(id) or !actor:is_character_loaded() then return end

  local cur_time = CurTime()

  if (actor.next_stats_roll or 0) > cur_time then
    Cable.send(actor, 'fl_stats_roll_result', id, nil)

    return
  end

  actor.next_stats_roll = cur_time + Stats.roll_interval

  local result = Stats:roll_and_announce(actor, id)

  Cable.send(actor, 'fl_stats_roll_result', id, result and roll_summary(result) or nil)
end)
