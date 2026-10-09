--- Server side of the Prop Protection plugin: gives and takes the ownership of entities,
-- removes the entities of owners who have left and hands them back to those who return,
-- charges and refunds the cost of props and keeps track of the props that must not hurt
-- players. Ownership lasts for the session of the server: it is kept on the entities and in
-- an index by ownership key, and nothing is written to the database.

local owned = PropProtection.owned or {}
local held = PropProtection.held or {}
PropProtection.owned = owned
PropProtection.held = held

--- Returns the name of the timer that removes the entities owned under a key.
-- @param key [String ownership key]
-- @return [String]
local function removal_timer(key)
  return 'fl_prop_removal_'..key
end

--- Takes an entity out of the index of owned entities, and stops the removal countdown of
-- its owner when it was the last entity they had.
-- @param key [String ownership key the entity is owned under]
-- @param entity [Entity]
local function unlist(key, entity)
  local entities = owned[key]

  if !entities then return end

  entities[entity] = nil

  if table.IsEmpty(entities) then
    owned[key] = nil
    timer.Remove(removal_timer(key))
  end
end

--- Makes an entity the property of the active character of a player, taking it from its
-- previous owner. Players, weapons and entities that are not networked cannot be owned.
-- Runs the PlayerCanOwnEntity hook before and the EntityOwnershipGiven hook after a change
-- of the owner; giving an entity to the character that already owns it changes nothing but
-- the permanent flag.
-- ```
-- PropProtection:give_ownership(actor, entity)
-- ```
-- @param actor [Player the new owner]
-- @param entity [Entity]
-- @param permanent=nil [Boolean true to keep the entity when its owner leaves, false to
--   remove it like any other; the current setting is kept when nil]
-- @return [Boolean whether the entity is now owned by the active character of the player]
function PropProtection:give_ownership(actor, entity, permanent)
  if !IsValid(actor) or !actor:IsPlayer() or !IsValid(entity) then return false end
  if entity:IsPlayer() or entity:IsWeapon() or entity:EntIndex() < 1 then return false end

  local key = self:get_key(actor)

  if !key then return false end

  local old_key = entity:get_nv('fl_prop_owner')

  if old_key == key then
    if permanent != nil then
      entity.prop_owner_permanent = permanent and true or nil
    end

    return true
  end

  --- Asks whether an entity may become the property of a player's active character. Called
  -- on the server before the ownership of an entity changes: for everything a player spawns
  -- from the spawn menu or creates with a tool, and when a plugin gives an entity away.
  -- @param actor [Player the player who is about to own the entity]
  -- @param entity [Entity]
  -- @return [Boolean return false to leave the entity with whoever owns it now, which is
  --   nobody for an entity that has just been spawned]
  if hook.Run('PlayerCanOwnEntity', actor, entity) == false then return false end

  if old_key then
    self:take_ownership(entity)
  end

  owned[key] = owned[key] or {}
  owned[key][entity] = true

  entity.prop_owner_permanent = permanent and true or nil
  entity:set_nv('fl_prop_owner', key)

  --- Called on the server after an entity has become the property of a player's active
  -- character.
  -- @param entity [Entity]
  -- @param actor [Player the new owner]
  -- @param key [String ownership key of the new owner, see PropProtection:get_key]
  hook.Run('EntityOwnershipGiven', entity, actor, key)

  return true
end

--- Makes an entity the property of nobody. Runs the EntityOwnershipTaken hook afterward.
-- @param entity [Entity]
-- @return [Boolean true if the entity had an owner]
function PropProtection:take_ownership(entity)
  if !IsValid(entity) then return false end

  local key = entity:get_nv('fl_prop_owner')

  if !key then return false end

  unlist(key, entity)

  entity.prop_owner_permanent = nil
  entity:set_nv('fl_prop_owner', nil)

  --- Called on the server after an entity has stopped being the property of a character
  -- while it still exists: it was given to somebody else, released by a plugin, or kept
  -- when the entities of an owner who had left were removed. Not called for entities that
  -- are removed.
  -- @param entity [Entity]
  -- @param key [String ownership key of the previous owner, see PropProtection:get_key]
  hook.Run('EntityOwnershipTaken', entity, key)

  return true
end

--- Forgets what the plugin keeps about an entity that is being removed: its place in the
-- index of owned entities and the player who holds it with the physics gun.
-- @param entity [Entity]
function PropProtection:forget_entity(entity)
  local key = entity:get_nv('fl_prop_owner')

  held[entity] = nil

  if key then
    unlist(key, entity)
  end
end

--- Returns the entities that are owned under a key.
-- @param key [String ownership key, see PropProtection:get_key]
-- @return [List<Entity>]
function PropProtection:get_owned_entities(key)
  local entities = {}

  if key and owned[key] then
    for entity, v in pairs(owned[key]) do
      if IsValid(entity) then
        table.insert(entities, entity)
      end
    end
  end

  return entities
end

--- Handles an entity that a player has just created: gives it to their active character and
-- makes it harmless to players for a while. The plugin calls it for everything that comes
-- out of the spawn menu and for everything Sandbox adds to the cleanup list of a player,
-- which covers what the tools create. Call it for entities that a player creates in any
-- other way.
-- @param actor [Player the player who created the entity]
-- @param entity [Entity]
-- @return [Boolean whether the entity is now owned by the active character of the player]
function PropProtection:entity_spawned(actor, entity)
  if !self:give_ownership(actor, entity) then return false end

  self:mark_harmless(entity)

  return true
end

--- Starts the removal countdown for the entities of a player's active character, as the
-- plugin does when the player disconnects or switches to another character. The entities
-- of players who are exempt from the rules are left alone unless the remove_staff_entities
-- config is on.
-- @param actor [Player]
-- @return [Boolean whether the countdown has been started]
-- @see [PropProtection#schedule_removal]
function PropProtection:abandon_entities(actor)
  if !Config.get('remove_staff_entities') and self:can_bypass(actor) then return false end

  return self:schedule_removal(self:get_key(actor))
end

--- Starts the countdown after which the entities owned under a key are removed. Does
-- nothing if nothing is owned under the key or the prop_removal_delay config is 0.
-- @param key [String ownership key, see PropProtection:get_key]
-- @return [Boolean whether the countdown has been started]
function PropProtection:schedule_removal(key)
  local delay = tonumber(Config.get('prop_removal_delay')) or 0

  if !key or delay <= 0 or !owned[key] then return false end

  timer.Create(removal_timer(key), delay, 1, function()
    PropProtection:remove_abandoned(key)
  end)

  return true
end

--- Removes the entities owned under a key, unless the owner is connected on that character.
-- Entities that were given as permanent stay owned. Static entities and those the
-- ShouldRemoveAbandonedEntity hook keeps are released instead of removed, so that they
-- belong to nobody from then on.
-- @param key [String ownership key, see PropProtection:get_key]
function PropProtection:remove_abandoned(key)
  timer.Remove(removal_timer(key))

  if self:find_owner(key) then return end

  for k, v in ipairs(self:get_owned_entities(key)) do
    if !v.prop_owner_permanent then
      local keep = v:GetPersistent()

      if !keep then
        --- Asks whether an entity should be removed now that its owner has been gone, or
        -- has been playing another character, for the time of the prop_removal_delay
        -- config. Called on the server for every entity of that owner that is neither
        -- permanent nor static.
        -- @param entity [Entity]
        -- @param key [String ownership key of the owner, see PropProtection:get_key]
        -- @return [Boolean return false to keep the entity, which then belongs to nobody]
        keep = hook.Run('ShouldRemoveAbandonedEntity', v, key) == false
      end

      if keep then
        self:take_ownership(v)
      else
        v:Remove()
      end
    end
  end
end

--- Stops the removal of the entities of a player's active character, which is how they
-- get their entities back when they reconnect or switch back to the character in time.
-- Notifies the player and runs the PlayerEntitiesReturned hook if a removal was pending.
-- @param actor [Player]
-- @return [List<Entity> the entities of the active character of the player]
function PropProtection:return_ownership(actor)
  local key = self:get_key(actor)

  if !key or !owned[key] then return {} end

  local timer_name = removal_timer(key)
  local was_abandoned = timer.Exists(timer_name)
  local entities = self:get_owned_entities(key)

  timer.Remove(timer_name)

  if was_abandoned and #entities > 0 then
    actor:notify('notification.prop_protection.returned', { count = #entities })

    --- Called on the server when a player has come back to their entities before they were
    -- removed: they have reconnected, or switched back to the character that owns them.
    -- @param actor [Player the owner]
    -- @param entities [List<Entity> the entities of their active character]
    hook.Run('PlayerEntitiesReturned', actor, entities)
  end

  return entities
end

--- Checks whether a player may do something to every entity that is constrained to an
-- entity, such as the parts of a contraption that the remover is about to delete together.
-- @param actor [Player]
-- @param entity [Entity]
-- @param action [String see PropProtection:can_manipulate]
-- @param detail=nil [String the tool ID or the property name]
-- @return [Boolean whether the action is allowed for all of them, String ID of the rule that
--   refuses it]
function PropProtection:can_manipulate_constrained(actor, entity, action, detail)
  for k, v in pairs(constraint.GetAllConstrainedEntities(entity)) do
    if IsValid(v) and v != entity then
      local allowed, rule = self:can_manipulate(actor, v, action, detail)

      if !allowed then
        return false, rule
      end
    end
  end

  return true
end

--- Tells a player why they may not touch an entity, at most once a second.
-- @param actor [Player]
-- @param rule=nil [String ID of the rule that has refused the action]
function PropProtection:notify_refusal(actor, rule)
  local cur_time = CurTime()

  if actor.next_protection_notice and actor.next_protection_notice > cur_time then return end

  actor.next_protection_notice = cur_time + 1

  if rule == 'owned' then
    actor:notify('error.prop_protection.not_yours')
  else
    actor:notify('error.prop_protection.protected')
  end
end

--- Returns what spawning a prop costs a player. Props are free when the prop_cost config is
-- 0, when the Currencies plugin is not loaded and for players who cannot hold money or have
-- no active character. The AdjustPropCost hook can change the price and the currency.
-- @param actor [Player]
-- @param model [String model of the prop]
-- @param entity=nil [Entity the prop, if it has been spawned already]
-- @return [Number the cost, rounded to the decimals of the currency, 0 if the prop is free;
--   String currency ID; Map currency definition (the last two only when there is a cost)]
function PropProtection:get_prop_cost(actor, model, entity)
  local base_cost = tonumber(Config.get('prop_cost')) or 0

  if base_cost <= 0 or !Currencies or !Characters then return 0 end
  if !IsValid(actor) or actor:IsBot() or !actor:is_character_loaded() then return 0 end
  if !actor:can_contain_money() then return 0 end

  local info = {
    cost = base_cost,
    currency = Config.get('default_currency')
  }

  --- Lets plugins change what a player pays for spawning a prop. Called on the server when
  -- the prop_cost config is above 0 and the player is able to pay: once before the prop is
  -- spawned, to check that they can afford it, and once after, to charge them. Every
  -- handler may change the table, so a handler should return nothing to let the others run.
  -- @param actor [Player the player who spawns the prop]
  -- @param model [String model of the prop]
  -- @param info [Map the price, modified in place: cost (Number the prop_cost config; 0 or
  --   less makes the prop free) and currency (String currency ID, the default_currency
  --   config)]
  -- @param entity [Entity the prop, nil when called before it is spawned]
  hook.Run('AdjustPropCost', actor, model, info, entity)

  local cost = tonumber(info.cost)
  local currency = isstring(info.currency) and info.currency:lower()
  local currency_data = currency and Currencies:find_currency(currency)

  if !cost or cost != cost or !currency_data then return 0 end

  cost = math.round(cost, currency_data.decimals or 0)

  if cost <= 0 then return 0 end

  return cost, currency, currency_data
end

--- Takes the cost of a spawned prop from the player who spawned it and remembers it on the
-- prop, so that it can be refunded if the prop is removed within the prop_refund_time
-- config. Notifies the player either way.
-- @param actor [Player]
-- @param model [String model of the prop]
-- @param entity [Entity the prop]
-- @return [Boolean false if the player cannot afford the prop, true otherwise]
function PropProtection:charge_prop_cost(actor, model, entity)
  local cost, currency, currency_data = self:get_prop_cost(actor, model, entity)

  if cost <= 0 then return true end

  if !actor:has_money(currency, cost) then
    actor:notify('error.prop_protection.cannot_afford', { value = cost, currency = currency_data.name })

    return false
  end

  actor:take_money(currency, cost)

  entity.prop_cost = {
    amount = cost,
    currency = currency,
    key = self:get_key(actor),
    refund_until = CurTime() + (tonumber(Config.get('prop_refund_time')) or 0)
  }

  actor:notify('notification.prop_protection.charged', { value = cost, currency = currency_data.name })

  return true
end

--- Gives the cost of a prop back to the character that paid for it, if the prop is within
-- its refund time and the player is connected on that character. A prop is refunded once.
-- @param entity [Entity the prop that is being removed]
-- @return [Boolean whether the cost has been refunded]
function PropProtection:refund_prop_cost(entity)
  local paid = entity.prop_cost

  if !paid then return false end

  entity.prop_cost = nil

  if Flux.shutting_down or !Currencies or paid.refund_until < CurTime() then return false end

  local owner = self:find_owner(paid.key)
  local currency_data = Currencies:find_currency(paid.currency)

  if !owner or !currency_data then return false end

  owner:give_money(paid.currency, paid.amount)
  owner:notify(
    'notification.prop_protection.refunded',
    { value = paid.amount, currency = currency_data.name },
    Color('lightgreen')
  )

  return true
end

--- Makes an entity harmless to players for the time of the prop_kill_protection_time
-- config, counted from now.
-- @param entity [Entity]
function PropProtection:mark_harmless(entity)
  entity.prop_harmless_until = CurTime() + (tonumber(Config.get('prop_kill_protection_time')) or 0)
end

--- Checks whether an entity is one whose impacts players are protected from: it is held
-- with the physics gun or carried by a player, or it has been spawned or dropped by the
-- physics gun within the prop_kill_protection_time config. Players, NPCs and weapons are
-- never harmless, and a vehicle is only while it is held.
-- @param entity [Entity]
-- @return [Boolean]
function PropProtection:is_harmless(entity)
  if !IsValid(entity) or entity:IsPlayer() or entity:IsNPC() or entity:IsWeapon() then
    return false
  end

  if IsValid(held[entity]) or entity:IsPlayerHolding() then
    return true
  end

  if entity:IsVehicle() then
    return false
  end

  return entity.prop_harmless_until != nil and entity.prop_harmless_until > CurTime()
end

if cleanup and (cleanup.fl_add or cleanup.Add) then
  cleanup.fl_add = cleanup.fl_add or cleanup.Add

  --- Replaces Sandbox's cleanup.Add, which every spawn command and every tool calls for the
  -- entities it creates, to give those entities to the player before they are added to the
  -- cleanup list of the player as usual.
  -- @param owner [Player the player who created the entity]
  -- @param kind [String cleanup type, such as 'props']
  -- @param entity [Entity]
  -- @return [Any whatever the original function returns]
  function cleanup.Add(owner, kind, entity)
    if IsValid(owner) and owner:IsPlayer() and IsValid(entity) then
      PropProtection:entity_spawned(owner, entity)
    end

    return cleanup.fl_add(owner, kind, entity)
  end
end
