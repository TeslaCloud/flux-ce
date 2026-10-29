--- Entity extension of the D20 plugin: the armor class of an NPC or any other entity.

local entity_meta = FindMetaTable('Entity')
local config_get = Config.get

--- Returns the armor class of the entity, which an attack roll against it has to reach to
-- hit: the 'd20_npc_armor_class' config, after the AdjustArmorClass hook. Players have
-- their own, see `Player:get_armor_class`.
-- @return [Number armor class]
function entity_meta:get_armor_class()
  return D20:adjust_armor_class(self, config_get('d20_npc_armor_class', 12))
end
