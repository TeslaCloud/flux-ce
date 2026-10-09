--- Server-side hooks of the Prop Protection plugin: the checks for freezing and unfreezing
-- with the physics gun, the ownership of everything that comes out of the spawn menu, the
-- cost of props, the protection of players from props, and the removal and return of the
-- entities of players who disconnect or switch characters.

--- Refuses to let a player freeze an entity that the rules protect from them. Nothing is
-- returned for everything else, so that the handlers of other plugins may still refuse and
-- the gamemode does the freezing.
-- @param weapon [Weapon the physics gun]
-- @param phys_obj [PhysObj the physics object that is being frozen]
-- @param entity [Entity the entity the physics object belongs to]
-- @param actor [Player the player who is trying to freeze it]
-- @return [Boolean false to refuse, nothing otherwise]
function PropProtection:OnPhysgunFreeze(weapon, phys_obj, entity, actor)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !self:can_manipulate(actor, entity, 'freeze') then
    return false
  end
end

--- Lets a player without the `physgun_freeze` permission freeze an entity that the rules
-- allow them, which is what lets players freeze their own entities. Entities that forbid the
-- physics gun themselves are left alone.
-- @param actor [Player the player who is trying to freeze the entity]
-- @param entity [Entity the entity that is being frozen]
-- @return [Boolean true to allow the freeze, nothing otherwise]
function PropProtection:PlayerCanPhysgunFreeze(actor, entity)
  if !IsValid(actor) or !IsValid(entity) or entity.PhysgunDisabled then return end

  if self:can_manipulate(actor, entity, 'freeze') then
    return true
  end
end

--- Refuses to let a player unfreeze an entity that the rules protect from them.
-- @param actor [Player]
-- @param entity [Entity the frozen entity]
-- @param phys_obj [PhysObj the physics object that is being unfrozen]
-- @return [Boolean false to refuse, nothing otherwise]
function PropProtection:CanPlayerUnfreeze(actor, entity, phys_obj)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !self:can_manipulate(actor, entity, 'unfreeze') then
    return false
  end
end

--- Remembers who holds an entity with the physics gun, so that it cannot hurt players
-- while it is held.
-- @param actor [Player the player who has picked the entity up]
-- @param entity [Entity]
function PropProtection:OnPhysgunPickup(actor, entity)
  if IsValid(entity) and !entity:IsPlayer() then
    self.held[entity] = actor
  end
end

--- Forgets who held an entity that the physics gun has let go of and keeps the entity
-- harmless to players for a while, so that it cannot be thrown at them.
-- @param actor [Player the player who has dropped the entity]
-- @param entity [Entity]
function PropProtection:PhysgunDrop(actor, entity)
  if IsValid(entity) and !entity:IsPlayer() then
    self.held[entity] = nil
    self:mark_harmless(entity)
  end
end

--- Keeps a player who cannot afford the cost of a prop from spawning it.
-- @param actor [Player]
-- @param model [String model of the prop]
-- @return [Boolean false if the player cannot pay for the prop, nothing otherwise]
function PropProtection:FLPlayerSpawnProp(actor, model)
  local cost, currency, currency_data = self:get_prop_cost(actor, model)

  if cost > 0 and !actor:has_money(currency, cost) then
    actor:notify('error.prop_protection.cannot_afford', { value = cost, currency = currency_data.name })

    return false
  end
end

--- Charges the player for the prop they have spawned, removing it if they cannot pay after
-- all, and makes the prop theirs.
-- @param actor [Player]
-- @param model [String model of the prop]
-- @param entity [Entity the prop]
function PropProtection:PlayerSpawnedProp(actor, model, entity)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !self:charge_prop_cost(actor, model, entity) then
    entity:Remove()

    return
  end

  self:entity_spawned(actor, entity)
end

--- Makes the ragdoll a player has spawned theirs.
-- @param actor [Player]
-- @param model [String model of the ragdoll]
-- @param entity [Entity the ragdoll]
function PropProtection:PlayerSpawnedRagdoll(actor, model, entity)
  self:entity_spawned(actor, entity)
end

--- Makes the effect a player has spawned theirs.
-- @param actor [Player]
-- @param model [String model of the effect]
-- @param entity [Entity the effect]
function PropProtection:PlayerSpawnedEffect(actor, model, entity)
  self:entity_spawned(actor, entity)
end

--- Makes the vehicle a player has spawned theirs.
-- @param actor [Player]
-- @param entity [Entity the vehicle]
function PropProtection:PlayerSpawnedVehicle(actor, entity)
  self:entity_spawned(actor, entity)
end

--- Makes the scripted entity a player has spawned theirs.
-- @param actor [Player]
-- @param entity [Entity]
function PropProtection:PlayerSpawnedSENT(actor, entity)
  self:entity_spawned(actor, entity)
end

--- Makes the NPC a player has spawned theirs.
-- @param actor [Player]
-- @param entity [Entity the NPC]
function PropProtection:PlayerSpawnedNPC(actor, entity)
  self:entity_spawned(actor, entity)
end

--- Blocks the impact damage a player would take from a harmless entity (one that is held
-- with the physics gun, or was spawned or dropped by it a moment ago) while the
-- prop_kill_protection config is on, and from being pushed into the world by one.
-- @param target [Entity the entity that is taking damage]
-- @param damage_info [CTakeDamageInfo]
-- @return [Boolean true to block the damage, nothing otherwise]
function PropProtection:EntityTakeDamage(target, damage_info)
  if !Config.get('prop_kill_protection') then return end
  if !IsValid(target) or !target:IsPlayer() or !damage_info:IsDamageType(DMG_CRUSH) then return end

  local cur_time = CurTime()
  local inflictor = damage_info:GetInflictor()
  local attacker = damage_info:GetAttacker()
  local prop = (self:is_harmless(inflictor) and inflictor) or (self:is_harmless(attacker) and attacker)

  if !prop then
    if attacker == game.GetWorld() and target.prop_push_until and target.prop_push_until > cur_time then
      return true
    end

    return
  end

  --- Asks whether a player should be hurt by an entity that the Prop Protection plugin
  -- considers harmless: one that is held with the physics gun, or was spawned or dropped by
  -- it within the prop_kill_protection_time config. Called on the server, while the
  -- prop_kill_protection config is on, before such impact damage is blocked.
  -- @param target [Player the player who is about to be protected]
  -- @param prop [Entity the entity that has hit them]
  -- @param damage_info [CTakeDamageInfo the damage]
  -- @return [Boolean return true to let the damage through]
  if hook.Run('PlayerShouldTakePropDamage', target, prop, damage_info) == true then return end

  target.prop_push_until = cur_time + 1

  return true
end

--- Refunds a prop that is removed within its refund time and forgets what the plugin kept
-- about the removed entity.
-- @param entity [Entity]
function PropProtection:EntityRemoved(entity)
  self:refund_prop_cost(entity)
  self:forget_entity(entity)
end

--- Starts the removal countdown for the entities of a player who disconnects.
-- @param actor [Player]
function PropProtection:PlayerDisconnected(actor)
  self:abandon_entities(actor)
end

--- Starts the removal countdown for the entities of the character a player switches away
-- from. Nothing happens when the player selects the character that is already active.
-- @param owner [Player]
-- @param new_char [Character the character that is about to become active]
-- @param old_char [Character the character that is still active]
function PropProtection:OnCharacterChange(owner, new_char, old_char)
  if new_char and old_char and new_char.id != nil and tonumber(new_char.id) == tonumber(old_char.id) then
    return
  end

  self:abandon_entities(owner)
end

--- Hands the entities of a character back to the player who has loaded it.
-- @param owner [Player]
-- @param character [Character the character that is now active]
function PropProtection:OnActiveCharacterSet(owner, character)
  self:return_ownership(owner)
end

--- Hands the entities that a player owned without a character back to them when they
-- reconnect, which is all there is to return on a server without the Characters plugin.
-- Done once their client has finished loading, so that the notification reaches it; until
-- then the entities are safe because their owner is connected.
-- @param actor [Player]
function PropProtection:PlayerInitialized(actor)
  self:return_ownership(actor)
end
