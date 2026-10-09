--- Limbs tracks how badly each body part of a character is hurt.
-- Every character has seven limbs: 'head', 'chest', 'stomach', 'left_arm', 'right_arm',
-- 'left_leg' and 'right_leg'. Each of them carries damage from 0 (healthy) to 100 (crippled).
-- The damage is kept in the generic data of the character under the 'limbs' key, so it is
-- saved with the character, and it is networked to the owner of the character and to nobody
-- else: a client only ever knows the limbs of the local player.
--
-- The server watches the damage that players take without changing it. A hit that was traced
-- to a body part hurts that limb, a hit on the ragdoll of a fallen player hurts the limb
-- closest to it, and fall damage is split between the legs. Damage without a location, such
-- as an explosion, hurts no limb unless an `AdjustLimbHits` handler says otherwise. Limbs do
-- not heal with health: they recover slowly on their own (the 'limbs_recovery' config), are
-- healed through `Limbs:heal` and `Limbs:heal_all`, which is what medical items should call,
-- and are reset when the player dies.
-- ```
-- -- A medical item that also treats the limbs of its user.
-- function ITEM:use(actor)
--   actor:SetHealth(math.min(actor:Health() + 25, actor:GetMaxHealth()))
--
--   if Limbs then
--     Limbs:heal_all(actor, 50)
--   end
-- end
-- ```
--
-- Hurt limbs get in the way, and every effect has its own config: hurt legs slow running
-- down and lower jumps ('limbs_legs_slow'), and hurt arms make the aim of a held weapon
-- drift ('limbs_arms_sway'). Other plugins read the strength of an effect with
-- `Limbs:get_effect` to slow down whatever they do with arms or legs, and the
-- `AdjustLimbEffect` hook changes it per player. The 'limbs_enabled' config turns the whole
-- system off: nothing is tracked, every limb reads as healthy and no effect applies.
--
-- The local player sees a small body diagram on the HUD while any limb is hurt, colored by
-- the damage of each limb. The 'limbs_hud' client setting changes when it is shown, the
-- `ShouldDrawLimbDiagram` hook hides it, and a theme can take over the drawing with a
-- `DrawLimbDiagram` method or move it with the 'limbs_diagram_x', 'limbs_diagram_y' and
-- 'limbs_diagram_height' options.
--
-- The `PlayerLimbDamaged`, `PlayerLimbHealed` and `PlayerLimbsReset` hooks report changes on
-- the server.
-- @module [Limbs]

PLUGIN:set_global('Limbs')

Limbs.data_key = 'limbs'
Limbs.max_damage = 100
Limbs.sway_angle = 1.5

local limb_ids = {
  'head',
  'chest',
  'stomach',
  'left_arm',
  'right_arm',
  'left_leg',
  'right_leg'
}

local limb_lookup = {}

for k, v in ipairs(limb_ids) do
  limb_lookup[v] = k
end

local hitgroup_limbs = {
  [HITGROUP_HEAD] = 'head',
  [HITGROUP_CHEST] = 'chest',
  [HITGROUP_STOMACH] = 'stomach',
  [HITGROUP_GEAR] = 'stomach',
  [HITGROUP_LEFTARM] = 'left_arm',
  [HITGROUP_RIGHTARM] = 'right_arm',
  [HITGROUP_LEFTLEG] = 'left_leg',
  [HITGROUP_RIGHTLEG] = 'right_leg'
}

local bone_limbs = {
  ['ValveBiped.Bip01_Head1'] = 'head',
  ['ValveBiped.Bip01_Neck1'] = 'head',
  ['ValveBiped.Bip01_Spine1'] = 'chest',
  ['ValveBiped.Bip01_Spine2'] = 'chest',
  ['ValveBiped.Bip01_Spine4'] = 'chest',
  ['ValveBiped.Bip01_L_Clavicle'] = 'chest',
  ['ValveBiped.Bip01_R_Clavicle'] = 'chest',
  ['ValveBiped.Bip01_Spine'] = 'stomach',
  ['ValveBiped.Bip01_Pelvis'] = 'stomach',
  ['ValveBiped.Bip01_L_UpperArm'] = 'left_arm',
  ['ValveBiped.Bip01_L_Forearm'] = 'left_arm',
  ['ValveBiped.Bip01_L_Hand'] = 'left_arm',
  ['ValveBiped.Bip01_R_UpperArm'] = 'right_arm',
  ['ValveBiped.Bip01_R_Forearm'] = 'right_arm',
  ['ValveBiped.Bip01_R_Hand'] = 'right_arm',
  ['ValveBiped.Bip01_L_Thigh'] = 'left_leg',
  ['ValveBiped.Bip01_L_Calf'] = 'left_leg',
  ['ValveBiped.Bip01_L_Foot'] = 'left_leg',
  ['ValveBiped.Bip01_L_Toe0'] = 'left_leg',
  ['ValveBiped.Bip01_R_Thigh'] = 'right_leg',
  ['ValveBiped.Bip01_R_Calf'] = 'right_leg',
  ['ValveBiped.Bip01_R_Foot'] = 'right_leg',
  ['ValveBiped.Bip01_R_Toe0'] = 'right_leg'
}

local leg_ids = { 'left_leg', 'right_leg' }
local arm_ids = { 'left_arm', 'right_arm' }

local limb_effects = {
  run = { config = 'limbs_legs_slow', limbs = leg_ids },
  jump = { config = 'limbs_legs_slow', limbs = leg_ids },
  aim = { config = 'limbs_arms_sway', limbs = arm_ids }
}

Characters.network_data(Limbs.data_key)

--- Checks whether limb damage is turned on by the 'limbs_enabled' config.
-- @return [Boolean]
function Limbs:is_enabled()
  return Config.get('limbs_enabled', true) and true or false
end

--- Returns the IDs of all limbs, from the head down.
-- @return [List<String> 'head', 'chest', 'stomach', 'left_arm', 'right_arm', 'left_leg' and
--   'right_leg'; do not modify the list]
function Limbs:all()
  return limb_ids
end

--- Checks whether a value is the ID of a limb.
-- @param limb [Any]
-- @return [Boolean]
function Limbs:is_limb(limb)
  return limb_lookup[limb] != nil
end

--- Returns the limb that a hit group belongs to.
-- ```
-- Limbs:from_hitgroup(HITGROUP_LEFTLEG) -- 'left_leg'
-- Limbs:from_hitgroup(HITGROUP_GENERIC) -- nil
-- ```
-- @param hitgroup [Number HITGROUP_ enum]
-- @return [String limb ID, or nil for HITGROUP_GENERIC and unknown hit groups; HITGROUP_GEAR
--   counts as the stomach]
function Limbs:from_hitgroup(hitgroup)
  return hitgroup_limbs[hitgroup]
end

--- Returns the limb that a bone of the ValveBiped skeleton belongs to.
-- @param bone_name [String name of the bone, e.g. 'ValveBiped.Bip01_L_Calf']
-- @return [String limb ID, or nil if the bone is not a known part of a limb]
function Limbs:from_bone(bone_name)
  return bone_limbs[bone_name]
end

--- Returns the language phrase of the name of a limb.
-- ```
-- target:notify('my_schema.bandaged', { limb = t(Limbs:get_limb_name('left_arm')) })
-- ```
-- @param limb [String limb ID]
-- @return [String phrase, e.g. 'ui.limbs.left_arm']
function Limbs:get_limb_name(limb)
  return 'ui.limbs.'..tostring(limb)
end

--- Returns the table that holds the limb damage of a player's active character, as it is
-- kept in the character data, whether limb damage is enabled or not.
-- @warning [Internal] Read limb damage with `Limbs:get_damage` and `Limbs:get_all_damage`.
-- @param target [Player]
-- @return [Map damage by limb ID, healthy limbs left out; nil if nothing is stored, the
--   player has no active character, or, on the client, the player is not the local player]
function Limbs:get_stored(target)
  if !IsValid(target) or !target:IsPlayer() then return end

  local stored = target:get_character_data(self.data_key)

  if istable(stored) then
    return stored
  end
end

--- Returns the damage of every hurt limb of a player. On the client only the limbs of the
-- local player are known.
-- @param target [Player]
-- @return [Map damage (1 to 100) by limb ID, healthy limbs left out; empty when limb damage
--   is disabled]
function Limbs:get_all_damage(target)
  local result = {}
  local stored = self:is_enabled() and self:get_stored(target)

  if stored then
    for k, v in ipairs(limb_ids) do
      local damage = tonumber(stored[v])

      if damage and damage > 0 then
        result[v] = math.min(damage, self.max_damage)
      end
    end
  end

  return result
end

--- Returns the damage of one limb of a player. On the client only the limbs of the local
-- player are known; those of other players read as healthy.
-- ```
-- if Limbs:get_damage(target, 'right_arm') >= 75 then
--   target:notify('my_schema.cannot_lift')
-- end
-- ```
-- @param target [Player]
-- @param limb [String limb ID]
-- @return [Number damage from 0 (healthy) to 100 (crippled); 0 when limb damage is disabled]
function Limbs:get_damage(target, limb)
  local stored = self:is_enabled() and self:get_stored(target)
  local damage = stored and limb_lookup[limb] and tonumber(stored[limb])

  if !damage or damage <= 0 then
    return 0
  end

  return math.min(damage, self.max_damage)
end

--- Returns how healthy one limb of a player is: 100 minus its damage.
-- @param target [Player]
-- @param limb [String limb ID]
-- @return [Number health of the limb from 0 (crippled) to 100 (healthy)]
-- @see [Limbs:get_damage]
function Limbs:get_health(target, limb)
  return self.max_damage - self:get_damage(target, limb)
end

--- Returns the damage of the most hurt limb among the given ones.
-- ```
-- local leg_damage = Limbs:get_worst_damage(target, { 'left_leg', 'right_leg' })
-- ```
-- @param target [Player]
-- @param limbs=nil [List<String> limb IDs to look at; all limbs when omitted]
-- @return [Number damage from 0 to 100]
function Limbs:get_worst_damage(target, limbs)
  local stored = self:is_enabled() and self:get_stored(target)
  local worst = 0

  if stored then
    for k, v in ipairs(limbs or limb_ids) do
      local damage = limb_lookup[v] and tonumber(stored[v])

      if damage and damage > worst then
        worst = damage
      end
    end
  end

  return math.min(worst, self.max_damage)
end

--- Checks whether any limb of a player is hurt.
-- @param target [Player]
-- @return [Boolean false when limb damage is disabled]
function Limbs:is_any_damaged(target)
  return self:get_worst_damage(target) > 0
end

--- Returns how strongly an effect of limb damage applies to a player. The plugin itself
-- uses 'run' (hurt legs slow running down), 'jump' (hurt legs lower jumps) and 'aim' (hurt
-- arms make the aim drift); the first two follow the 'limbs_legs_slow' config and the worse
-- leg, the third follows the 'limbs_arms_sway' config and the worse arm. Other plugins can
-- use the same values for their own penalties.
-- ```
-- -- Picking a lock takes up to twice as long with a hurt arm.
-- local duration = 10 * (1 + (Limbs and Limbs:get_effect(actor, 'aim') or 0))
-- ```
-- @param target [Player on the client only the local player has effects]
-- @param effect [String 'run', 'jump' or 'aim']
-- @return [Number strength from 0 (no effect) to 1 (the limb is crippled)]
function Limbs:get_effect(target, effect)
  local info = limb_effects[effect]

  if !info or !Config.get(info.config, true) then
    return 0
  end

  local fraction = self:get_worst_damage(target, info.limbs) / self.max_damage

  if fraction <= 0 then
    return 0
  end

  --- Lets plugins change how strongly an effect of limb damage applies to a player, for
  -- example to make a faction immune to it. Called on both realms whenever the strength of an
  -- effect is asked for and the limbs behind it are hurt: for 'run' and 'jump' on every
  -- movement command of the player, for 'aim' on every frame of the local player. On the
  -- client it is only ever called for the local player. Movement is predicted, so a handler
  -- for 'run' or 'jump' has to be shared and return the same value on both realms.
  -- @param target [Player The player the effect applies to]
  -- @param effect [String 'run', 'jump' or 'aim']
  -- @param fraction [Number Strength from the damage of the limbs, above 0 and up to 1]
  -- @return [Number Strength to use instead, from 0 (no effect) to 1; nothing to keep it]
  local override = hook.Run('AdjustLimbEffect', target, effect, fraction)

  if isnumber(override) then
    fraction = math.Clamp(override, 0, 1)
  end

  return fraction
end

require_relative 'sv_plugin'
require_relative 'sh_hooks'
require_relative 'sv_hooks'
require_relative 'cl_plugin'
require_relative 'cl_hooks'
