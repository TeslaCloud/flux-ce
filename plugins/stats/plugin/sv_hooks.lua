--- Server hook handlers of the Stats plugin: load the attribute records, with their boosts,
-- and the skill records together with the characters, give characters their attribute and
-- skill records, network a character's attributes and skills when it becomes active and
-- remove its boosts as they expire, check the stats of new characters, keep the stat bonuses
-- of the faction on every character, apply the effects of the stats through the hooks of the
-- Chatbox, Stamina, Pickup Objects, Damage, Limb Damage and Vendors plugins and warn about
-- mistakes in the definitions of attributes and skills. The rolls that a player asks for
-- with the 'fl_stats_roll' message are in `nethooks/sv_stats.lua`. A handler of a plugin
-- that is not loaded is never called.

local IsValid = IsValid
local isnumber = isnumber
local math_max = math.max

--- Prints the names of a map that are missing from a list, in development mode.
-- @param kind [String 'attribute' or 'skill']
-- @param id [String ID of the definition]
-- @param map [Map the levels or the ranks of the definition]
-- @param order [List<String> the level or rank order of the definition]
local function warn_unordered(kind, id, map, order)
  if !istable(map) or !istable(order) then return end

  for key in pairs(map) do
    if !table.HasValue(order, key) then
      Flux.dev_print('The '..kind..' \''..id..'\' names \''..tostring(key)..'\', which its order does not list.')
    end
  end
end

--- Warns in development mode about the mistakes in the definitions of attributes and skills
-- that would otherwise go unnoticed: a skill whose key stat is not registered, an attribute
-- whose `creation_max` is above its `max`, and a level or rank that `level_order` or
-- `rank_order` does not list.
function Stats:PluginsLoaded()
  for id, attribute_table in pairs(Attributes.get_stored()) do
    local creation_max = tonumber(attribute_table.creation_max)

    if creation_max and creation_max > attribute_table.max then
      Flux.dev_print('The attribute \''..id..'\' has a creation_max above its max.')
    end

    warn_unordered('attribute', id, attribute_table.levels, attribute_table.level_order)
  end

  for id, skill in pairs(Skills.get_stored()) do
    if isstring(skill.attribute) and !Attributes.find(skill.attribute) then
      Flux.dev_print('The skill \''..id..'\' has the key stat \''..skill.attribute..'\', which is not registered.')
    end

    warn_unordered('skill', id, skill.ranks, skill.rank_order)
  end
end

--- Loads the attribute records of characters, with their boosts, and their skill records
-- together with them.
-- @param preloads [Map relations of the characters, changed in place]
function Stats:AdjustCharacterPreloads(preloads)
  local attributes = preloads.attributes or {}

  attributes[#attributes + 1] = 'attribute_boosts'
  preloads.attributes = attributes
  preloads[#preloads + 1] = 'skills'
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
function Stats:ActiveCharacterSet(owner, character)
  Attributes.create_records(character)
  Attributes.remove_expired(owner)
  Attributes.sync(owner)
  Skills.create_records(character)
  Skills.sync(owner)

  self:apply_faction_bonuses(owner)
end

--- Takes the networked attributes and skills of a character away from the player who drops
-- it, and forgets the levels kept of its attributes, when its next boost expires and the
-- fractions of effects carried over.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Stats:ActiveCharacterCleared(owner, _character)
  owner.attribute_expiry = nil
  owner.attribute_character = nil
  owner.attribute_levels = nil
  owner.attribute_totals = nil
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
function Stats:PlayerFactionChanged(target, _faction_table, _old_faction)
  self:apply_faction_bonuses(target)
end

--- Gives or takes the faction bonuses of everyone online when the `stats_faction_bonuses`
-- config changes.
-- @param key [String config key]
-- @param old_value [Any]
-- @param new_value [Any]
function Stats:ConfigChanged(key, old_value, new_value)
  if key != 'stats_faction_bonuses' or old_value == new_value then return end

  for _, client in player.Iterator() do
    self:apply_faction_bonuses(client)
  end
end

--- Extends the hearing radius of in character messages by the `stats_perception_hearing`
-- config, 1.5 meters by default, for every level of the listener's perception, and shortens
-- it for every level below zero.
-- Only a message that has a hearing range is changed. The Chatbox plugin sends a message
-- with a radius of 0 to everyone and one with a negative radius to nobody but the players
-- that the PlayerCanHearChat hook lets through, which is how a radio transmission that is not
-- overheard is sent, so those radii are left alone. For the same reason a shortened radius
-- never falls below `Stats.min_hearing_radius`: at 0 the message would reach everyone.
-- @param listener [Player player hearing the message]
-- @param message_data [Map chat message data]
function Stats:AdjustChatMessageData(listener, message_data)
  local radius = message_data.radius

  if !message_data.ic or !isnumber(radius) or radius <= 0 then return end

  local meters = tonumber(Config.get('stats_perception_hearing')) or 0

  if meters == 0 then return end

  local level = listener:get_attribute('perception')

  if level == 0 then return end

  message_data.radius = math_max(radius + Unit:meter(level * meters), self.min_hearing_radius)
end

--- Rejects new characters unless each stat that is not hidden has a whole level between its
-- minimum and its creation limit, no level is given for any other ID and the levels add up
-- to the points a new character gets.
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
    if !stats[stat_id] or stats[stat_id].hidden then
      return CHAR_ERR_ATTRIBUTE_SUM
    end
  end

  for stat_id, stat in pairs(stats) do
    if !stat.hidden then
      local level = levels[stat_id]

      if !isnumber(level) or level != math.floor(level) or level < stat.min or level > self:get_creation_max(stat) then
        return CHAR_ERR_ATTRIBUTE_SUM
      end

      sum += level
    end
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
function Stats:GetStaminaDrainScale(target)
  local scale = self:get_player_effect_scale(target, 'endurance', 'stats_endurance_stamina', true)

  if scale != 1 then
    return scale
  end
end

--- Makes the stamina of a player regenerate faster by the `stats_endurance_stamina` config
-- for every level of their endurance, and slower for every level below zero.
-- @param target [Player player who is recovering]
-- @return [Number multiplier of the regeneration rate, nil to leave it alone]
function Stats:GetStaminaRegenScale(target)
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
function Stats:AdjustThrow(actor, _ent, info)
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
    return self:scale_whole(target, 'health', amount, scale)
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
    return self:scale_whole(actor, 'limbs', amount, scale)
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
