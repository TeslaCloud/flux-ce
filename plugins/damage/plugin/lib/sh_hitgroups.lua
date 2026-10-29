--- Hit locations, on both realms: the limbs that the hit groups of the engine belong to and
-- the phrases of their names. A hit group is the HITGROUP_ enum that the engine reports for a
-- bullet or melee hit; a limb is one of seven IDs, 'head', 'chest', 'stomach', 'left_arm',
-- 'right_arm', 'left_leg' and 'right_leg'. HITGROUP_GEAR, the gear that a model wears,
-- counts as the stomach. HITGROUP_GENERIC and unknown hit groups belong to no limb and are
-- named 'ui.limbs.body'.

if !Damage then
  PLUGIN:set_global('Damage')
end

local isnumber = isnumber

--- IDs of the limbs, from the head down.
const limb_ids = {
  'head',
  'chest',
  'stomach',
  'left_arm',
  'right_arm',
  'left_leg',
  'right_leg'
}

--- Limb of every hit group that belongs to one.
const hitgroup_limbs = {
  [HITGROUP_HEAD] = 'head',
  [HITGROUP_CHEST] = 'chest',
  [HITGROUP_STOMACH] = 'stomach',
  [HITGROUP_GEAR] = 'stomach',
  [HITGROUP_LEFTARM] = 'left_arm',
  [HITGROUP_RIGHTARM] = 'right_arm',
  [HITGROUP_LEFTLEG] = 'left_leg',
  [HITGROUP_RIGHTLEG] = 'right_leg'
}

--- Phrase of the name of every limb, by limb ID.
const limb_names = {}

for _, limb_id in ipairs(limb_ids) do
  limb_names[limb_id] = 'ui.limbs.'..limb_id
end

--- Returns the IDs of all limbs, from the head down.
-- @return [List<String> 'head', 'chest', 'stomach', 'left_arm', 'right_arm', 'left_leg' and
--   'right_leg'; do not modify the list]
function Damage:get_limbs()
  return limb_ids
end

--- Returns the limb that a hit group belongs to.
-- ```
-- Damage:get_limb(HITGROUP_LEFTLEG) -- 'left_leg'
-- Damage:get_limb(HITGROUP_GEAR) -- 'stomach'
-- Damage:get_limb(HITGROUP_GENERIC) -- nil
-- ```
-- @param hitgroup [Number HITGROUP_ enum]
-- @return [String limb ID, or nil for HITGROUP_GENERIC and unknown hit groups]
function Damage:get_limb(hitgroup)
  return hitgroup_limbs[hitgroup]
end

--- Returns the language phrase of the name of a hit location.
-- ```
-- t(Damage:get_limb_name(HITGROUP_HEAD)) -- 'Head'
-- t(Damage:get_limb_name('left_arm')) -- 'Left arm'
-- t(Damage:get_limb_name(HITGROUP_GENERIC)) -- 'Body'
-- ```
-- @param location [Number/String HITGROUP_ enum or limb ID]
-- @return [String phrase, e.g. 'ui.limbs.left_arm'; 'ui.limbs.body' for a location that
--   belongs to no limb]
function Damage:get_limb_name(location)
  if isnumber(location) then
    location = hitgroup_limbs[location]
  end

  return limb_names[location] or 'ui.limbs.body'
end
