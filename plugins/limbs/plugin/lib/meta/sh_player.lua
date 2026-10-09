--- Player extensions of the Limbs plugin: shorthands for reading the limb damage of a player
-- on either realm and for hurting, healing and resetting their limbs on the server.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Returns the damage of one limb of the player. On the client only the limbs of the local
-- player are known.
-- ```
-- if actor:get_limb_damage('left_leg') > 50 then
--   actor:notify('my_schema.cannot_climb')
-- end
-- ```
-- @param limb [String limb ID: 'head', 'chest', 'stomach', 'left_arm', 'right_arm',
--   'left_leg' or 'right_leg']
-- @return [Number damage from 0 (healthy) to 100 (crippled); 0 when limb damage is disabled]
-- @see [Limbs:get_damage]
function player_meta:get_limb_damage(limb)
  return Limbs:get_damage(self, limb)
end

--- Returns the damage of every hurt limb of the player. On the client only the limbs of the
-- local player are known.
-- @return [Map damage (1 to 100) by limb ID, healthy limbs left out]
-- @see [Limbs:get_all_damage]
function player_meta:get_limbs()
  return Limbs:get_all_damage(self)
end

--- Checks whether a limb of the player is hurt.
-- @param limb=nil [String limb ID; any limb when omitted]
-- @return [Boolean]
function player_meta:is_limb_damaged(limb)
  if limb == nil then
    return Limbs:is_any_damaged(self)
  end

  return Limbs:get_damage(self, limb) > 0
end

if SERVER then
  --- Hurts one limb of the player. Server only.
  -- @param limb [String limb ID]
  -- @param amount [Number damage to add]
  -- @return [Number the damage that was added]
  -- @see [Limbs:damage]
  function player_meta:damage_limb(limb, amount)
    return Limbs:damage(self, limb, amount)
  end

  --- Heals one limb of the player. Server only.
  -- @param limb [String limb ID]
  -- @param amount=100 [Number damage to take off; heals the limb completely when omitted]
  -- @return [Number the damage that was taken off]
  -- @see [Limbs:heal]
  function player_meta:heal_limb(limb, amount)
    return Limbs:heal(self, limb, amount)
  end

  --- Heals every hurt limb of the player by the same amount. Server only.
  -- ```
  -- actor:heal_limbs(25)
  -- ```
  -- @param amount=100 [Number damage to take off each limb; heals the limbs completely when
  --   omitted]
  -- @return [Number the damage that was taken off all limbs together]
  -- @see [Limbs:heal_all]
  function player_meta:heal_limbs(amount)
    return Limbs:heal_all(self, amount)
  end

  --- Clears the damage of all limbs of the player at once. Server only.
  -- @return [Boolean true if any limb was hurt]
  -- @see [Limbs:reset]
  function player_meta:reset_limbs()
    return Limbs:reset(self)
  end
end
