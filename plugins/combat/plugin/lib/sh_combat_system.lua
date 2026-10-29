--- Combat bookkeeping and the rolls of the turn based combat. Every attack between a player
-- and an NPC or another player is an attack roll of the D20 plugin (`D20:attack_roll`): a d20
-- plus the attack modifier of the attacker against the armor class of the target. The combat
-- adds a bonus to that roll for the range of the weapon, the recoil of a weak shooter and the
-- body part that was aimed at. The turn order is rolled as initiative: a reflexes roll of the
-- Stats plugin for players and a d20 plus the 'd20_npc_attack_bonus' config for NPCs.

local tonumber = tonumber
local isfunction = isfunction
local math_ceil = math.ceil
local config_get = Config.get

if !CombatSystem then
  PLUGIN:set_global('CombatSystem')
end

local stored = CombatSystem.stored or {}
CombatSystem.stored = stored

--- Stores a combat.
-- @param combat [Combat combat to store]
-- @return [Number ID of the stored combat]
function CombatSystem:add(combat)
  return table.insert(stored, combat)
end

--- Removes a stored combat.
-- @param id [Number ID of the combat]
function CombatSystem:remove(id)
  stored[id] = nil
end

--- Returns a stored combat.
-- @param id [Number ID of the combat]
-- @return [Combat combat, nil if it does not exist]
function CombatSystem:find(id)
  return stored[id]
end

--- Adds an entity to a combat.
-- @param combat [Combat combat to add the entity to]
-- @param member [Entity player or NPC to add]
function CombatSystem:add_member(combat, member)
  combat:add_member(member)
end

--- Adds every entity within 500 units that the member can see to a combat.
-- @param combat [Combat combat to add the entities to]
-- @param member [Entity entity to search around]
function CombatSystem:add_entities_around(combat, member)
  local entities = ents.FindInSphere(member:GetPos(), 500)
  local pos = member:EyePos()
  local filter = entity -> !isentity(entity)

  for i = 1, #entities do
    local entity = entities[i]

    if !util.vector_obstructed(pos, entity:EyePos(), filter) then
      combat:add_member(entity)
    end
  end
end

--- Starts a combat between an attacker and a target, pulling in everyone around them.
-- @param attacker [Entity entity that started the fight]
-- @param target [Entity entity that was attacked]
-- @return [Combat started combat]
function CombatSystem:start_combat(attacker, target)
  local combat = Combat.new()
  self:add_member(combat, attacker)
  self:add_member(combat, target)
  self:add_entities_around(combat, attacker)
  self:add_entities_around(combat, target)

  combat:start()

  return combat
end

--- Bonus of an attack roll by the body part that was aimed at.
local hitgroup_adjust = {
  [HITGROUP_GENERIC]    = 0,
  [HITGROUP_HEAD]       = -2,
  [HITGROUP_CHEST]      = 0,
  [HITGROUP_STOMACH]    = 0,
  [HITGROUP_LEFTARM]    = 2,
  [HITGROUP_RIGHTARM]   = 2,
  [HITGROUP_LEFTLEG]    = 2,
  [HITGROUP_RIGHTLEG]   = 2,
  [HITGROUP_GEAR]       = 0
}

--- Rolls whether an attack hits with `D20:attack_roll` and announces the result to the
-- combat. The attack roll gets a bonus that adds up the following:
-- * range, for a player whose weapon item has an `effective_distance`: -2 for every step of
--   the effective distance that the target is beyond it, +2 within 5 meters; the
--   AdjustAttackDistance hook can change both distances first;
-- * recoil: -2 for every shot the attacker has already fired this turn, while the strength
--   modifier of the attacker is negative;
-- * body part: -2 for the head, +2 for an arm or a leg, nothing for the rest, at the hit
--   location that `Damage:get_hitgroup` reports.
-- A natural 20 always hits and a natural 1 always misses; both are announced as critical.
-- Every message carries the formatted roll and the armor class it was rolled against.
-- Serverside only.
-- @param attacker [Entity attacking player or NPC]
-- @param target [Entity player or NPC being attacked]
-- @param damage_info [CTakeDamageInfo damage of the attack]
-- @return [Boolean true if the attack missed, false if it hit]
function CombatSystem:calculate_hit(attacker, target, damage_info)
  local combat = attacker:get_combat() or target:get_combat()
  local adjust = 0
  local hitgroup = Damage:get_hitgroup(target)

  if attacker:IsPlayer() then
    local weapon_item = attacker:get_active_weapon_item()

    if weapon_item and weapon_item.effective_distance then
      local data = {
        attacker = attacker,
        target = target,
        distance = attacker:EyePos():Distance(damage_info:GetDamagePosition()),
        effective_distance = weapon_item.effective_distance or 0,
        distance_adjust = 0,
        combat = combat
      }

      --- Lets plugins change the distances that the range bonus of an attack roll in turn
      -- based combat is worked out from. Called on the server for every attack of a player
      -- whose weapon item has an `effective_distance`, before the attack roll. While the
      -- effective distance stays above 0, the bonus is worked out afterwards: -2 for every
      -- step of the effective distance that the target is beyond it and +2 within 5 meters;
      -- in between, or with an effective distance of 0, the `distance_adjust` of the table
      -- is used as it is. Every handler may change the table, so a handler should return
      -- nothing to let the others run.
      -- ```
      -- -- Scopes double the effective distance of a weapon.
      -- function MyPlugin:AdjustAttackDistance(data)
      --   if data.attacker:has_item_equipped('scope') then
      --     data.effective_distance = data.effective_distance * 2
      --   end
      -- end
      -- ```
      -- @param data [Map Modified in place: attacker (Player the attacking player), target
      --   (Entity the entity being attacked), distance (Number units from the eyes of the
      --   attacker to where the damage landed), effective_distance (Number units the weapon
      --   is accurate up to), distance_adjust (Number bonus of the attack roll for the range,
      --   0), combat (Combat the combat of the attack)]
      hook.Run('AdjustAttackDistance', data)

      if data.effective_distance > 0 then
        if data.distance > data.effective_distance then
          data.distance_adjust = -2 * math_ceil((data.distance - data.effective_distance) / data.effective_distance)
        elseif data.distance < (5):m() then
          data.distance_adjust = 2
        end
      end

      adjust += data.distance_adjust
    end

    if attacker.shots_done and attacker.shots_done > 0 and attacker:get_attribute_modifier('strength') < 0 then
      adjust -= 2 * attacker.shots_done
    end
  end

  adjust += hitgroup_adjust[hitgroup] or 0

  attacker.shots_done = (attacker.shots_done or 0) + 1

  local hit, result, armor_class = D20:attack_roll(attacker, target, {
    bonus = adjust,
    hitgroup = hitgroup,
    damage_info = damage_info
  })

  local arguments = {
    attacker = attacker,
    target = target,
    limb = Damage:get_limb_name(hitgroup),
    roll = Dice.format(result),
    armor_class = armor_class
  }

  if hit then
    if target:IsPlayer() and target.combat_leaving then
      target.combat_leaving = false
      target:notify('notification.combat.leave_interrupt')
    end

    if result.critical == 'success' then
      combat:send_message('notification.combat.critical_success', arguments)
    else
      combat:send_message('notification.combat.success', arguments)
    end

    return false
  end

  if result.critical == 'failure' then
    combat:send_message('notification.combat.critical_failure', arguments)
  else
    combat:send_message('notification.combat.fail', arguments)
  end

  return true
end

--- Rolls the initiative of a combat member. A player rolls their reflexes
-- (`Player:roll_attribute`), or a plain d20 when that roll cannot be made; anything else
-- rolls a d20 plus the 'd20_npc_attack_bonus' config.
-- @param entity [Entity combat member]
-- @return [Number total of the initiative roll]
function CombatSystem:dice_initiative(entity)
  local result

  if entity:IsPlayer() then
    if isfunction(entity.roll_attribute) then
      result = entity:roll_attribute('reflexes')
    end
  else
    result = Dice.roll('1d20 + bonus', { bonus = tonumber(config_get('d20_npc_attack_bonus', 2)) or 0 })
  end

  result = result or Dice.roll('1d20')

  return result.total
end
