--- Entity methods of the turn based combat: whether an entity is in a combat, and which.

local ent_meta = FindMetaTable('Entity')

--- Checks whether the entity is a member of a combat.
-- @return [Boolean whether the entity is in combat]
function ent_meta:in_combat()
  return isnumber(self:get_nv('combat_id', nil))
end

--- Returns the combat the entity is a member of.
-- @return [Combat combat of the entity, nil if it is not in one]
function ent_meta:get_combat()
  return CombatSystem:find(self:get_nv('combat_id'))
end
