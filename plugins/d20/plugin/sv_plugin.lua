--- Server side of the D20 plugin: the dice of weapons and NPCs, the formula of a hit, the
-- rolls of hits and falls, and the health of NPCs. The hooks that call these functions are
-- in `sv_hooks.lua`.

local IsValid = IsValid
local CurTime = CurTime
local pairs = pairs
local ipairs = ipairs
local istable = istable
local isstring = isstring
local isfunction = isfunction
local tonumber = tonumber
local tostring = tostring
local config_get = Config.get
local math_max = math.max
local math_floor = math.floor
local math_round = math.Round

--- Dice formulas of weapons and of the projectiles they fire, by entity class.
local weapon_dice = {
  weapon_fists = '1d4',
  weapon_stunstick = '1d4',
  weapon_crowbar = '1d6',
  weapon_pistol = '1d6',
  weapon_smg1 = '1d6',
  weapon_357 = '1d10',
  weapon_ar2 = '1d10',
  weapon_shotgun = '1d10',
  weapon_crossbow = '1d12',
  weapon_rpg = '1d12',
  weapon_frag = '1d12',
  crossbow_bolt = '1d12',
  rpg_missile = '1d12',
  npc_grenade_frag = '1d12',
  grenade_ar2 = '1d12',
  prop_combine_ball = '1d12'
}

--- Dice formulas of the attacks of NPCs that fight with their own body, by NPC class.
local npc_dice = {
  npc_zombie = '1d6',
  npc_zombie_torso = '1d6',
  npc_fastzombie = '1d6',
  npc_fastzombie_torso = '1d6',
  npc_zombine = '1d6',
  npc_poisonzombie = '1d10',
  npc_headcrab = '1d4',
  npc_headcrab_fast = '1d4',
  npc_headcrab_black = '1d4',
  npc_headcrab_poison = '1d4',
  npc_antlion = '1d6',
  npc_antlion_worker = '1d6',
  npc_antlionguard = '1d12',
  npc_manhack = '1d4',
  npc_hunter = '1d10',
  npc_strider = '1d12'
}

--- Dice formulas of damage types, in the order they are checked, each with the name of the
-- type for the source of the formula.
local damage_type_dice = {
  { DMG_BURN, '1d4', 'burn' },
  { DMG_SLOWBURN, '1d4', 'burn' },
  { DMG_BLAST, '1d12', 'blast' },
  { DMG_CRUSH, '1d10', 'crush' }
}

--- Dice formulas by the damage of the engine: the first band whose limit the damage does not
-- exceed applies, and damage above every limit rolls `highest_band_dice`.
local damage_bands = {
  { 10, '1d4' },
  { 20, '1d6' },
  { 40, '1d10' }
}

local highest_band_dice = '1d12'

--- Reads one of the override configs, 'd20_weapon_dice' or 'd20_npc_dice', into a map.
-- Entries of the list are strings like 'weapon_pistol = 1d8'; a map of formulas by class is
-- taken as well. Classes are matched in lower case.
-- @param key [String config key]
-- @return [Map dice formula by class]
local function read_overrides(key)
  local overrides = {}
  local value = config_get(key)

  if !istable(value) then
    return overrides
  end

  for k, v in pairs(value) do
    if isstring(k) and isstring(v) then
      overrides[k:lower()] = v
    elseif isstring(v) then
      local class, formula = v:match('^%s*([^%s=]+)%s*=%s*(.-)%s*$')

      if class and formula != '' then
        overrides[class:lower()] = formula
      end
    end
  end

  return overrides
end

--- Checks a formula that is about to be stored, when the Dice library can tell.
-- @param formula [String]
-- @return [Boolean whether it can be rolled, String the error if it cannot]
local function check_formula(formula)
  if !isstring(formula) or formula == '' then
    return false, 'the formula is empty'
  end

  if Dice and isfunction(Dice.is_valid) then
    return Dice.is_valid(formula, D20:get_variables())
  end

  return true
end

--- Sets the dice formula of a weapon or projectile class, which a hit dealt with it rolls
-- unless the weapon item of the attacker has `damage_dice` of its own. An entry of the
-- 'd20_weapon_dice' config for the class still wins. Serverside only.
-- ```
-- D20:set_weapon_dice('weapon_pistol', '1d8')
-- D20:set_weapon_dice('weapon_crowbar', nil) -- falls back to the damage type and bands
-- ```
-- @param class [String entity class, matched in lower case]
-- @param formula [String dice formula, or nil to remove the dice of the class]
-- @return [Boolean whether the dice were set, String the error if the formula cannot be
--   rolled]
function D20:set_weapon_dice(class, formula)
  if !isstring(class) then
    return false, 'the class is not a string'
  end

  if formula != nil then
    local valid, err = check_formula(formula)

    if !valid then
      return false, err
    end
  end

  weapon_dice[class:lower()] = formula

  return true
end

--- Returns the dice formula of a weapon or projectile class: the entry of the
-- 'd20_weapon_dice' config for it if there is one, otherwise what the plugin or
-- `D20:set_weapon_dice` gives it. Serverside only.
-- @param class [String entity class]
-- @return [String dice formula, nil if the class has none]
function D20:get_weapon_dice(class)
  if !isstring(class) then return end

  class = class:lower()

  return read_overrides('d20_weapon_dice')[class] or weapon_dice[class]
end

--- Sets the dice formula of the attacks of an NPC class, which its hits roll when they do
-- not come from a weapon that has dice. An entry of the 'd20_npc_dice' config for the class
-- still wins. Serverside only.
-- ```
-- D20:set_npc_dice('npc_zombie', '2d6')
-- ```
-- @param class [String NPC class, matched in lower case]
-- @param formula [String dice formula, or nil to remove the dice of the class]
-- @return [Boolean whether the dice were set, String the error if the formula cannot be
--   rolled]
function D20:set_npc_dice(class, formula)
  if !isstring(class) then
    return false, 'the class is not a string'
  end

  if formula != nil then
    local valid, err = check_formula(formula)

    if !valid then
      return false, err
    end
  end

  npc_dice[class:lower()] = formula

  return true
end

--- Returns the dice formula of the attacks of an NPC class: the entry of the 'd20_npc_dice'
-- config for it if there is one, otherwise what the plugin or `D20:set_npc_dice` gives it.
-- Serverside only.
-- @param class [String NPC class]
-- @return [String dice formula, nil if the class has none]
function D20:get_npc_dice(class)
  if !isstring(class) then return end

  class = class:lower()

  return read_overrides('d20_npc_dice')[class] or npc_dice[class]
end

--- Returns the weapon item that a hit was dealt with: the item of the weapon a player
-- attacker holds, as long as the damage comes from that weapon and not from a projectile.
-- Needs the Inventory plugin. Serverside only.
-- @param attacker [Entity]
-- @param victim [Entity]
-- @param weapon_class [String class of what has dealt the damage, see
--   `Damage:get_weapon_class`]
-- @return [Item the weapon item, nil if there is none]
function D20:get_attack_weapon_item(attacker, victim, weapon_class)
  if !IsValid(attacker) or !attacker:IsPlayer() or attacker == victim then return end
  if !isfunction(attacker.get_active_weapon_item) then return end

  local weapon = attacker:GetActiveWeapon()

  if !IsValid(weapon) or weapon:GetClass() != weapon_class then return end

  return attacker:get_active_weapon_item()
end

--- Works out the dice formula that a hit rolls, in this order: the `damage_dice` of the
-- weapon item the hit was dealt with, the dice of the class of the weapon or projectile
-- (`D20:get_weapon_dice`), the dice of the class of an NPC attacker (`D20:get_npc_dice`),
-- the dice of the damage type (1d4 for burns, 1d12 for explosions, 1d10 for crushing blows),
-- and last the dice of the damage of the engine: 1d4 up to 10, 1d6 up to 20, 1d10 up to 40,
-- 1d12 above, and the 'd20_default_dice' config when it is 0. Fall damage and drowning have
-- no formula here: falls roll in `D20:roll_fall_damage` and drowning in the Damage plugin.
-- Serverside only.
-- ```
-- D20:get_damage_formula(attacker, victim, damage_info)
-- -- '1d6', 'weapon:weapon_pistol'
-- ```
-- @param attacker [Entity entity responsible for the damage]
-- @param victim [Entity entity taking the damage]
-- @param damage_info [CTakeDamageInfo the damage]
-- @return [String dice formula, String where it comes from: 'item:<item id>',
--   'weapon:<class>', 'npc:<class>', 'type:<burn, blast or crush>', 'damage' or 'default';
--   nothing for fall damage and drowning]
function D20:get_damage_formula(attacker, victim, damage_info)
  if damage_info:IsFallDamage() or damage_info:IsDamageType(DMG_DROWN) then return end

  local weapon_class = Damage:get_weapon_class(attacker, damage_info:GetInflictor(), victim)

  if weapon_class then
    local weapon_item = self:get_attack_weapon_item(attacker, victim, weapon_class)

    if weapon_item and isstring(weapon_item.damage_dice) and weapon_item.damage_dice != '' then
      return weapon_item.damage_dice, 'item:'..tostring(weapon_item.id)
    end

    local formula = self:get_weapon_dice(weapon_class)

    if formula then
      return formula, 'weapon:'..weapon_class
    end
  end

  if IsValid(attacker) and attacker:IsNPC() then
    local class = attacker:GetClass()
    local formula = self:get_npc_dice(class)

    if formula then
      return formula, 'npc:'..class
    end
  end

  for k, v in ipairs(damage_type_dice) do
    if damage_info:IsDamageType(v[1]) then
      return v[2], 'type:'..v[3]
    end
  end

  local damage = damage_info:GetDamage()

  if !damage or damage <= 0 or damage != damage then
    return config_get('d20_default_dice', '1d6'), 'default'
  end

  for k, v in ipairs(damage_bands) do
    if damage <= v[1] then
      return v[2], 'damage'
    end
  end

  return highest_band_dice, 'damage'
end

--- Returns the variables that a damage formula can use: `damage`, the damage of the engine;
-- `level`, the level of a player attacker when the Levels plugin is loaded, 1 otherwise; and
-- every stat by its ID, such as `strength`: the modifier of a player attacker when the Stats
-- plugin is loaded, 0 for anybody else, so that a formula with a stat in it can be rolled
-- for an NPC holding the weapon as well. Serverside only.
-- ```
-- D20:get_variables(attacker, damage_info)
-- -- { damage = 12, level = 3, strength = 2, reflexes = 1, ... }
-- ```
-- @param attacker=nil [Entity entity responsible for the damage]
-- @param damage_info=nil [CTakeDamageInfo the damage]
-- @return [Map numbers by variable name]
function D20:get_variables(attacker, damage_info)
  local variables = {
    damage = damage_info and damage_info:GetDamage() or 0,
    level = 1
  }

  local is_player = IsValid(attacker) and attacker:IsPlayer()

  if is_player and isfunction(attacker.get_level) then
    variables.level = tonumber(attacker:get_level()) or 1
  end

  if Attributes and ATTRIBUTE_STAT then
    local has_modifiers = is_player and isfunction(attacker.get_attribute_modifier)

    for id in pairs(Attributes.get_by_type(ATTRIBUTE_STAT)) do
      variables[id] = has_modifiers and tonumber(attacker:get_attribute_modifier(id)) or 0
    end
  end

  return variables
end

--- Rolls a formula, falling back to the 'd20_default_dice' config and then to 1d6 when it
-- cannot be rolled. The error is printed in development mode.
-- @param formula [String]
-- @param variables [Map]
-- @param what [String what the formula is for, for the error message]
-- @return [Map the Dice result, nil only when not even 1d6 can be rolled]
local function roll_or_default(formula, variables, what)
  local result, err = Dice.roll(formula, variables)

  if result then
    return result
  end

  Flux.dev_print('Invalid '..what..' formula \''..tostring(formula)..'\': '..tostring(err))

  result = Dice.roll(config_get('d20_default_dice', '1d6'), variables)

  return result or Dice.roll('1d6')
end

--- Replaces the damage of a hit on a player or an NPC with the total of its dice formula
-- (`D20:get_damage_formula`), after the AdjustDamageDice hook, rounded and never below 0,
-- times the hit location multiplier. Runs the PlayerDamageRolled hook with the result.
-- Damage events from the same attacker and inflictor that hit the same victim in the same
-- tick count as one attack: the first one rolls and the others are to be blocked. Does
-- nothing while the plugin is disabled, for fall damage and for drowning. Serverside only.
-- @param victim [Entity player or NPC taking the damage]
-- @param damage_info [CTakeDamageInfo the damage, changed in place]
-- @param scale=1 [Number hit location multiplier to apply to the rolled total]
-- @return [Boolean true when the damage is part of an attack that has already been rolled
--   and has to be blocked, nil otherwise]
function D20:roll_damage(victim, damage_info, scale)
  if !self:is_enabled() or !Dice then return end
  if damage_info:IsFallDamage() or damage_info:IsDamageType(DMG_DROWN) then return end

  local attacker, inflictor = damage_info:GetAttacker(), damage_info:GetInflictor()
  local cur_time = CurTime()

  if victim.d20_attack_time == cur_time and victim.d20_attacker == attacker and victim.d20_inflictor == inflictor then
    return true
  end

  local formula, source = self:get_damage_formula(attacker, victim, damage_info)

  if !formula then return end

  victim.d20_attack_time = cur_time
  victim.d20_attacker = attacker
  victim.d20_inflictor = inflictor

  local info = {
    formula = formula,
    variables = self:get_variables(attacker, damage_info),
    source = source
  }

  --- Lets plugins change the dice that a hit on a player or an NPC rolls. Called on the
  -- server for every hit that is rolled, after the formula has been picked and before the
  -- roll, while the 'd20_enabled' config is on. Not called for fall damage, drowning and the
  -- extra damage events of an attack that has already been rolled. Every handler may change
  -- the table, so a handler should return nothing to let the others run.
  -- ```
  -- -- Hits from behind roll an extra die.
  -- function MyPlugin:AdjustDamageDice(attacker, victim, damage_info, info)
  --   if IsValid(attacker) and victim:GetAimVector():Dot(attacker:GetAimVector()) > 0.5 then
  --     info.formula = '('..info.formula..') + 1d6'
  --   end
  -- end
  -- ```
  -- @param attacker [Entity The entity responsible for the damage]
  -- @param victim [Entity The player or NPC taking the damage]
  -- @param damage_info [CTakeDamageInfo The damage, still with the amount of the engine;
  --   changing the amount has no effect]
  -- @param info [Map Modified in place: formula (String the dice formula to roll),
  --   variables (Map the variables of the formula, see `D20:get_variables`), source (String
  --   where the formula comes from, see `D20:get_damage_formula`)]
  hook.Run('AdjustDamageDice', attacker, victim, damage_info, info)

  local result = roll_or_default(info.formula, info.variables, 'damage dice')

  if !result then return end

  damage_info:SetDamage(math_max(math_round(result.total * (scale or 1)), 0))

  --- Called on the server after the damage of a hit on a player or an NPC has been rolled
  -- and set, before the damage is dealt. The damage can still be changed or blocked by the
  -- damage handlers that run afterwards. The return value is ignored: return nothing, so
  -- that other handlers run.
  -- @param attacker [Entity The entity responsible for the damage]
  -- @param victim [Entity The player or NPC taking the damage]
  -- @param damage_info [CTakeDamageInfo The damage, with the rolled amount times the hit
  --   location multiplier]
  -- @param result [Map The Dice result of the roll: total, formula, rolls, natural and
  --   critical, see `Dice.roll`]
  -- @param info [Map The formula, variables and source that were rolled, see
  --   AdjustDamageDice]
  hook.Run('PlayerDamageRolled', attacker, victim, damage_info, result, info)
end

--- Remembers the damage of a bullet or melee hit on an NPC before the `ScaleNPCDamage`
-- handlers of the schema and of the gamemode multiply it, so that their multiplier can be
-- applied to the rolled damage. Damage that several pellets deal in the same tick adds up.
-- Serverside only.
-- @param npc [NPC]
-- @param damage_info [CTakeDamageInfo the damage before the multipliers]
function D20:remember_npc_damage(npc, damage_info)
  local cur_time = CurTime()

  if npc.d20_scale_time == cur_time then
    npc.d20_unscaled_damage = npc.d20_unscaled_damage + damage_info:GetDamage()
  else
    npc.d20_unscaled_damage = damage_info:GetDamage()
    npc.d20_scale_time = cur_time
  end
end

--- Returns the hit location multiplier that the `ScaleNPCDamage` handlers have applied to
-- the damage an NPC is taking, and forgets the damage that `D20:remember_npc_damage` has
-- kept for it. Serverside only.
-- @param npc [NPC]
-- @param damage_info [CTakeDamageInfo the damage after the multipliers]
-- @return [Number multiplier; 1 for damage that was not a bullet or melee hit]
function D20:take_npc_damage_scale(npc, damage_info)
  local unscaled = npc.d20_scale_time == CurTime() and npc.d20_unscaled_damage

  npc.d20_scale_time = nil
  npc.d20_unscaled_damage = nil

  if !unscaled or unscaled <= 0 then
    return 1
  end

  return damage_info:GetDamage() / unscaled
end

--- Rolls the fall damage of a player: the 'd20_fall_dice' config, `{steps}d6` by default,
-- where `steps` is the fall speed above 250 in steps of 150, at least 1. The
-- 'damage_scale_fall' config of the Damage plugin multiplies the total afterwards. A formula
-- that cannot be rolled falls back to `steps` d6. Serverside only.
-- ```
-- D20:roll_fall_damage(actor, 700) -- 3d6
-- ```
-- @param actor [Player the player who has hit the ground]
-- @param speed [Number fall speed]
-- @return [Number damage, nil while the plugin is disabled]
function D20:roll_fall_damage(actor, speed)
  if !self:is_enabled() or !Dice then return end

  local steps = math_max(1, math_floor((speed - 250) / 150))
  local variables = { steps = steps, speed = speed }
  local formula = config_get('d20_fall_dice', '{steps}d6')
  local result, err = Dice.roll(formula, variables)

  if !result then
    Flux.dev_print('Invalid fall damage formula \''..tostring(formula)..'\': '..tostring(err))

    result = Dice.roll(steps..'d6')
  end

  if !result then return end

  return math_max(math_round(result.total), 0)
end

--- Multiplies the maximum health of an NPC by the 'd20_npc_health_scale' config and sets
-- its health to the new maximum, at least 1. Every NPC is scaled once; NPCs without a
-- maximum health are left alone. Does nothing while the plugin is disabled. Serverside only.
-- @param npc [NPC]
-- @return [Boolean whether the health of the NPC was scaled]
function D20:scale_npc_health(npc)
  if !self:is_enabled() or !IsValid(npc) or !npc:IsNPC() or npc.d20_health_scaled then
    return false
  end

  local max_health = npc:GetMaxHealth()

  if max_health <= 0 then
    return false
  end

  local new_max_health = math_max(1, math_round(max_health * config_get('d20_npc_health_scale', 0.25)))

  npc.d20_health_scaled = true
  npc:SetMaxHealth(new_max_health)
  npc:SetHealth(new_max_health)

  return true
end

--- Checks the dice formulas of the configs of the plugin, and prints those that cannot be
-- rolled in development mode. Serverside only.
-- @param key [String config key]
-- @param value [Any value of the config]
function D20:check_config(key, value)
  if !Dice then return end

  if key == 'd20_default_dice' then
    local valid, err = Dice.is_valid(value, self:get_variables())

    if !valid then
      Flux.dev_print('Invalid d20_default_dice formula \''..tostring(value)..'\': '..tostring(err))
    end
  elseif key == 'd20_fall_dice' then
    local valid, err = Dice.is_valid(value, { steps = 1, speed = 526 })

    if !valid then
      Flux.dev_print('Invalid d20_fall_dice formula \''..tostring(value)..'\': '..tostring(err))
    end
  elseif key == 'd20_weapon_dice' or key == 'd20_npc_dice' then
    for class, formula in pairs(read_overrides(key)) do
      local valid, err = Dice.is_valid(formula, self:get_variables())

      if !valid then
        Flux.dev_print('Invalid '..key..' formula for '..class..' \''..formula..'\': '..tostring(err))
      end
    end
  end
end
