--- Player extension of the D20 plugin: the armor class of a player.

local isfunction = isfunction
local tonumber = tonumber
local player_meta = FindMetaTable('Player')

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
    value += tonumber(self:get_attribute_modifier('reflexes')) or 0
  end

  if self:Armor() > 0 then
    value += 2
  end

  return D20:adjust_armor_class(self, value)
end
