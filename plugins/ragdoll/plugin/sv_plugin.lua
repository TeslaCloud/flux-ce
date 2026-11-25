--- Server functions of the Ragdoll plugin that other plugins ask: whether damage to a fallen
-- player hits their hidden entity rather than the ragdoll that stands in for their body.

local IsValid = IsValid

--- Damage types that the world deals to a body where it lies: explosions, fire, shots, melee
-- hits and impacts.
const body_damage_types = DMG_BLAST | DMG_BURN | DMG_BULLET | DMG_CLUB | DMG_SLASH | DMG_CRUSH

--- Tells whether damage dealt to a player hits the hidden entity of a living player who has
-- fallen over rather than their body. While they are down their body is the ragdoll, which
-- passes the damage it takes on to them; the hidden entity still lies where they fell, in
-- the reach of explosions and fire. Damage of blast, fire, bullet, melee or crush types is
-- refused there unless the ragdoll is passing it on; falls, drowning and every other type
-- reach the player. The plugin's `EntityTakeDamage` handler blocks what this refuses, and
-- the Damage plugin asks it first in its own handler, so that no hit location, roll or
-- combat turn is worked out for damage that is blocked.
-- ```
-- if Ragdoll and Ragdoll:hits_hidden_body(victim, damage_info) then
--   return true
-- end
-- ```
-- @param target [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
-- @return [Boolean true if the damage hits the hidden entity of a fallen player and is to be
--   blocked]
function Ragdoll:hits_hidden_body(target, damage_info)
  if !IsValid(target) or !target:IsPlayer() or target.fl_ragdoll_forwarding or !target:Alive() then
    return false
  end

  local data = target.ragdoll_data

  if !data or !data.fallen or !IsValid(data.entity) then return false end

  return (damage_info:GetDamageType() & body_damage_types) != 0
end
