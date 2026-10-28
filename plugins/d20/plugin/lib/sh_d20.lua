--- Armor class and attack rolls of the D20 plugin. The armor class of a player or an NPC is
-- what an attack roll against them has to reach to hit; an attack roll is a d20 plus the
-- attack modifier of the attacker. The armor class and the attack modifier are known on both
-- realms, the attack roll itself is made on the server.
--
-- This file is included before sh_plugin.lua, which is why it is the one that makes the
-- plugin available as the `D20` global.

local IsValid = IsValid
local isnumber = isnumber
local isfunction = isfunction
local tonumber = tonumber
local config_get = Config.get

if !D20 then
  PLUGIN:set_global('D20')
end

local function adjust_armor_class(target, value)
  local info = { value = value }

  --- Lets plugins change the armor class of a player or an NPC, which an attack roll against
  -- them has to reach to hit. Called on either realm every time `get_armor_class` is called
  -- on a player or an entity, after the armor class has been worked out: 10, plus the
  -- reflexes of a player, plus 2 while they wear armor; the 'd20_npc_armor_class' config for
  -- anything else. Every handler may change the table, so a handler should return nothing to
  -- let the others run.
  -- ```
  -- -- Riot shields make their bearer harder to hit.
  -- function MyPlugin:AdjustArmorClass(target, info)
  --   if target:IsPlayer() and target:has_item('riot_shield') then
  --     info.value = info.value + 2
  --   end
  -- end
  -- ```
  -- @param target [Entity The player or NPC whose armor class is asked for]
  -- @param info [Map Modified in place: value (Number the armor class)]
  hook.Run('AdjustArmorClass', target, info)

  return tonumber(info.value) or value
end

do
  local entity_meta = FindMetaTable('Entity')
  local player_meta = FindMetaTable('Player')

  --- Returns the armor class of the entity, which an attack roll against it has to reach to
  -- hit: the 'd20_npc_armor_class' config, after the AdjustArmorClass hook. Players have
  -- their own, see `Player:get_armor_class`.
  -- @return [Number armor class]
  function entity_meta:get_armor_class()
    return adjust_armor_class(self, config_get('d20_npc_armor_class', 12))
  end

  --- Returns the armor class of the player, which an attack roll against them has to reach
  -- to hit: 10, plus the modifier of their reflexes when the Stats plugin is loaded, plus 2
  -- while they have any armor, after the AdjustArmorClass hook.
  -- ```
  -- target:get_armor_class() -- 10 + 2 reflexes + 2 armor = 14
  -- ```
  -- @return [Number armor class]
  function player_meta:get_armor_class()
    local value = 10

    if isfunction(self.get_attribute_modifier) then
      value = value + (tonumber(self:get_attribute_modifier('reflexes')) or 0)
    end

    if self:Armor() > 0 then
      value = value + 2
    end

    return adjust_armor_class(self, value)
  end
end

--- Checks whether a player attacks from a distance with the weapon they hold. The weapon
-- item decides when it has a `weapon_type` that is `WEAPON_RANGED` or `WEAPON_MELEE` (enums
-- that a schema may define); otherwise a weapon that uses primary ammo is ranged and any
-- other weapon, or no weapon at all, is melee.
-- @param attacker [Player]
-- @return [Boolean true for a ranged attack, false for a melee attack]
function D20:is_ranged_attack(attacker)
  if isfunction(attacker.get_active_weapon_item) then
    local weapon_item = attacker:get_active_weapon_item()
    local weapon_type = weapon_item and weapon_item.weapon_type

    if weapon_type != nil then
      if WEAPON_RANGED != nil and weapon_type == WEAPON_RANGED then
        return true
      elseif WEAPON_MELEE != nil and weapon_type == WEAPON_MELEE then
        return false
      end
    end
  end

  local weapon = attacker:GetActiveWeapon()

  return IsValid(weapon) and weapon:GetPrimaryAmmoType() != -1
end

--- Returns what an attacker adds to the d20 of an attack roll. A player adds the modifier of
-- their marksmanship skill for a ranged attack and of their close combat skill for a melee
-- attack (see `D20:is_ranged_attack`), when the Stats plugin is loaded; an NPC adds the
-- 'd20_npc_attack_bonus' config; anything else adds nothing.
-- @param attacker [Entity]
-- @return [Number attack modifier]
function D20:get_attack_modifier(attacker)
  if !IsValid(attacker) then
    return 0
  end

  if attacker:IsPlayer() then
    if !isfunction(attacker.get_skill_modifier) then
      return 0
    end

    local skill_id = self:is_ranged_attack(attacker) and 'marksmanship' or 'close_combat'

    return tonumber(attacker:get_skill_modifier(skill_id)) or 0
  elseif attacker:IsNPC() then
    return config_get('d20_npc_attack_bonus', 2)
  end

  return 0
end

--- Builds the formula of an attack roll: a d20 plus a modifier.
-- @param modifier [Number]
-- @return [String formula such as '1d20 + 5', '1d20 - 2' or '1d20']
function D20:get_attack_formula(modifier)
  if modifier > 0 then
    return '1d20 + '..modifier
  elseif modifier < 0 then
    return '1d20 - '..-modifier
  end

  return '1d20'
end

if SERVER then
  --- Rolls whether an attack hits: a d20 plus the attack modifier of the attacker (see
  -- `D20:get_attack_modifier`) and any `bonus` of the info table, after the AdjustAttackRoll
  -- hook, against the armor class of the target. The attack hits when the total reaches the
  -- armor class; a natural 20 always hits and a natural 1 always misses. A formula that cannot
  -- be rolled falls back to a plain d20 plus the modifier. Serverside only.
  -- ```
  -- local hit, result, armor_class = D20:attack_roll(attacker, target, { bonus = 2 })
  --
  -- attacker:notify(Dice.format(result)..(hit and ' hits' or ' misses')..' AC '..armor_class)
  -- ```
  -- @param attacker [Entity player or NPC making the attack]
  -- @param target [Entity player, NPC or other entity being attacked]
  -- @param info={} [Map optional: bonus (Number added to the roll), formula (String to roll
  --   instead of the d20 plus the modifier), armor_class (Number to roll against instead of
  --   the armor class of the target), variables (Map or function of the formula variables);
  --   filled in and passed to the hook]
  -- @return [Boolean whether the attack hits, Map the Dice result of the roll, Number the armor
  --   class it was rolled against]
  function D20:attack_roll(attacker, target, info)
    info = info or {}

    local modifier = self:get_attack_modifier(attacker) + (tonumber(info.bonus) or 0)

    info.modifier = modifier
    info.formula = info.formula or self:get_attack_formula(modifier)

    if !isnumber(info.armor_class) then
      info.armor_class = IsValid(target) and target:get_armor_class() or 10
    end

    --- Lets plugins change an attack roll before it is made. Called on the server from
    -- `D20:attack_roll`, after the formula and the armor class have been worked out. Every
    -- handler may change the table, so a handler should return nothing to let the others
    -- run.
    -- ```
    -- -- Attacking from behind is easier.
    -- function MyPlugin:AdjustAttackRoll(attacker, target, info)
    --   if target:GetAimVector():Dot(attacker:GetAimVector()) > 0.5 then
    --     info.formula = info.formula..' + 2'
    --   end
    -- end
    -- ```
    -- @param attacker [Entity The player or NPC making the attack]
    -- @param target [Entity The entity being attacked]
    -- @param info [Map Modified in place: formula (String the dice formula to roll, '1d20 + 5'
    --   for a modifier of 5), armor_class (Number what the total has to reach to hit),
    --   modifier (Number the attack modifier and bonus, already part of the formula), bonus
    --   (Number the bonus given to `D20:attack_roll`, if any), variables (Map or function of
    --   the formula variables, if any)]
    hook.Run('AdjustAttackRoll', attacker, target, info)

    local armor_class = tonumber(info.armor_class) or 10
    local result, err = Dice.roll(info.formula, info.variables)

    if !result then
      Flux.dev_print('Invalid attack roll formula \''..tostring(info.formula)..'\': '..tostring(err))

      result = Dice.roll(self:get_attack_formula(modifier))
    end

    local hit = result.total >= armor_class

    if result.critical == 'success' then
      hit = true
    elseif result.critical == 'failure' then
      hit = false
    end

    return hit, result, armor_class
  end
end
