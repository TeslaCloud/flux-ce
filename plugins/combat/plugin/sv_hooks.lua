--- Server hooks of the turn based combat: starting and joining combats when players and NPCs
-- attack each other, rolling the attacks, taking the turns of players for what they do, and
-- removing the dead and the removed from their combats.

local config_get = Config.get

local function leave_combat(combat, entity)
  local was_acting = combat:get_acting_member() == entity

  combat:remove_member(entity)
  combat:check()

  if was_acting and !combat.finished then
    combat:next_turn()
  end
end

--- Removes a killed NPC from its combat and ends the combat if it is over.
-- @param npc [NPC killed NPC]
-- @param attacker [Entity entity that killed the NPC]
function CombatSystem:OnNPCKilled(npc, attacker)
  local combat = npc:get_combat() or IsValid(attacker) and attacker:get_combat()

  if combat then
    leave_combat(combat, npc)
  end
end

--- Removes a deleted entity from its combat and ends the combat if it is over.
-- @param entity [Entity removed entity]
function CombatSystem:EntityRemoved(entity)
  local combat = entity:get_combat()

  if combat then
    leave_combat(combat, entity)
  end
end

--- Removes a dead player from their combat and ends the combat if it is over.
-- @param target [Player player that died]
-- @param _inflictor [Entity entity that dealt the damage]
-- @param attacker [Entity entity responsible for the death]
function CombatSystem:PlayerDeath(target, _inflictor, attacker)
  local combat = target:get_combat() or IsValid(attacker) and attacker:get_combat()

  if combat then
    leave_combat(combat, target)
  end
end

--- Blocks weapon switching without an attack turn in combat, otherwise switching uses up all attack turns.
-- @param actor [Player player switching weapons]
-- @return [Boolean true to block the switch, nil otherwise]
function CombatSystem:PlayerSwitchWeapon(actor)
  if actor:in_combat() then
    if actor:is_frozen() or !actor:has_turn(TURN_ATTACK) then
      return true
    else
      actor:take_turn(TURN_ATTACK, actor:get_turns(TURN_ATTACK))
    end
  end
end

--- Uses up all of a player's attack turns when they reload during their combat turn.
-- @param actor [Player player playing the animation event]
-- @param event [Number PLAYERANIMEVENT_ enum]
function CombatSystem:DoAnimationEvent(actor, event)
  if event == PLAYERANIMEVENT_RELOAD and actor:in_combat() and !actor:is_frozen() then
    actor:take_turn(TURN_ATTACK, actor:get_turns(TURN_ATTACK))
  end
end

--- Prevents players from raising their weapon in combat without an attack turn.
-- @param actor [Player player raising the weapon]
-- @return [Boolean false to prevent raising, nil otherwise]
function CombatSystem:PlayerCanRaiseWeapon(actor)
  if actor:in_combat() and (actor:is_frozen() or !actor:has_turn(TURN_ATTACK)) then
    return false
  end
end

--- Keeps weapons lowered in combat while the player has no attack turn.
-- @param actor [Player player holding the weapon]
-- @param _weapon [Weapon held weapon]
-- @return [Boolean false to keep the weapon lowered, nil otherwise]
function CombatSystem:ShouldWeaponBeRaised(actor, _weapon)
  if actor:in_combat() and (actor:is_frozen() or !actor:has_turn(TURN_ATTACK)) then
    return false
  end
end

--- Prevents players from using items in combat without a move turn.
-- @param actor [Player player using the item]
-- @param _item_obj [Item item being used]
-- @param _action [String action being performed]
-- @return [Boolean false to prevent the use, nil otherwise]
function CombatSystem:PlayerCanUseItem(actor, _item_obj, _action, ...)
  if actor:in_combat() and (actor:is_frozen() or !actor:has_turn(TURN_MOVE)) then
    return false
  end
end

--- Prevents players from moving inventory items in combat without a move turn.
-- @param actor [Player player moving the item]
-- @param _item_obj [Item item being moved]
-- @param _instance_ids [List<Number> instance IDs being moved]
-- @param _inventory_id [Number ID of the target inventory]
-- @param _x [Number target slot column]
-- @param _y [Number target slot row]
-- @return [Boolean false to prevent the move, nil otherwise]
function CombatSystem:PlayerCanMoveItem(actor, _item_obj, _instance_ids, _inventory_id, _x, _y)
  if actor:in_combat() and (actor:is_frozen() or !actor:has_turn(TURN_MOVE)) then
    return false
  end
end

--- Uses up a move turn when a player uses an item in combat.
-- @param actor [Player player that used the item]
-- @param _item_obj [Item used item]
-- @param _act [String action that was performed]
function CombatSystem:PlayerUsedItem(actor, _item_obj, _act, ...)
  if actor:in_combat() and !actor:is_frozen() then
    actor:take_turn(TURN_MOVE)
  end
end

--- Uses up a move turn when a player moves an inventory item in combat.
-- @param actor [Player player that moved the item]
-- @param _item_obj [Item moved item]
-- @param _instance_ids [List<Number> moved instance IDs]
-- @param _inventory_id [Number ID of the target inventory]
-- @param _x [Number target slot column]
-- @param _y [Number target slot row]
function CombatSystem:OnItemMoved(actor, _item_obj, _instance_ids, _inventory_id, _x, _y)
  if actor:in_combat() and !actor:is_frozen() then
    actor:take_turn(TURN_MOVE)
  end
end

--- Ends the player's combat turn. Players who have not acted yet also try to leave the combat.
-- @param actor [Player player that pressed the key]
function CombatSystem:ShowHelp(actor)
  if actor:in_combat() and !actor:is_frozen() then
    if !actor.turn_done then
      actor:notify('notification.combat.leave_try')
      actor.combat_leaving = true
    else
      actor:notify('notification.combat.skip')
    end

    actor:get_combat():next_turn()
  end
end

--- Joins a combat when a player and an NPC or another player fight and one of them is in a
-- combat, or starts one when neither is and the 'combat_auto_start' config is on, then rolls
-- whether the attack hits (see `CombatSystem:calculate_hit`) and uses up an attack turn of a
-- player attacker. A missed attack is blocked; a hit is left alone, so the damage that the
-- D20 plugin has rolled for it is dealt. An attack outside of a combat that starts none is
-- left alone as well.
--
-- The plugin depends on the D20 and Damage plugins, which load first, so this handler runs
-- after theirs. The damage of a hit on a player is rolled by `D20:ResolvePlayerDamage`, which
-- the Damage plugin's `EntityTakeDamage` handler calls; the damage of a hit on an NPC is
-- rolled by `D20:EntityTakeDamage`, as the Damage plugin rolls only the damage of players,
-- through `ResolvePlayerDamage`. Both have rolled by the time this handler runs, and the
-- extra damage events of an attack they have rolled already (shotgun pellets) are blocked
-- before they get here.
-- @param entity [Entity entity being damaged]
-- @param damage_info [CTakeDamageInfo damage being dealt]
-- @return [Boolean true to block the damage when the attack missed, nil when it hit or combat does not apply]
function CombatSystem:EntityTakeDamage(entity, damage_info)
  local attacker = damage_info:GetAttacker()

  if IsValid(attacker) and IsValid(entity)
  and ((attacker:IsPlayer() or attacker:IsNPC()) and (entity:IsPlayer() or entity:IsNPC()))
  and !(attacker:IsNPC() and entity:IsNPC()) then
    local attacker_combat = attacker:get_combat()
    local entity_combat = entity:get_combat()

    if attacker_combat and !entity_combat then
      CombatSystem:add_member(attacker_combat, entity)
    elseif !attacker_combat and entity_combat then
      CombatSystem:add_member(entity_combat, attacker)
    elseif !attacker_combat and !entity_combat then
      if !config_get('combat_auto_start') then return end

      CombatSystem:start_combat(attacker, entity)
    end

    local missed = CombatSystem:calculate_hit(attacker, entity, damage_info)

    if attacker:IsPlayer() and !attacker:is_frozen() then
      attacker:take_turn(TURN_ATTACK)
    end

    if missed then
      return true
    end
  end
end

--- Prevents frozen players from auto walking.
-- @param actor [Player player trying to auto walk]
-- @return [Boolean false to prevent it, nil otherwise]
function CombatSystem:PlayerCanAutoWalk(actor)
  if actor:is_frozen() then
    return false
  end
end
