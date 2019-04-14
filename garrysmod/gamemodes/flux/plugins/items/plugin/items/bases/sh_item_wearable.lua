if !ItemEquipable then
  require_relative 'sh_item_equipable'
end

class 'ItemWearable' extends 'ItemEquipable'

ItemWearable.name = 'Clothing Base'
ItemWearable.description = 'Clothes that can be equipped.'
ItemWearable.category = 'item.category.clothing'
ItemWearable.equip_inv = 'equipment'
ItemWearable.equip_slot = 'item.slot.chest'
-- Bodygroups example:
-- ItemWearable.equip_bodygroups = {
--   [0] = 0, -- Sets bodygroup #0 to 0
--   [1] = 1, -- Sets bodygroup #1 to 1
--            -- (valid for every model)
--   ['mask'] = 1 -- Sets bodygroup named 'mask' to 1
--                -- (only if model actually has this bodygroup)
-- }

if CLIENT then
  function ItemWearable:get_icon_model()
    if self:get_equip_model(PLAYER) then
      return self:get_equip_model(PLAYER)
    end
  end
end

function ItemWearable:get_equip_model(player)
  return self.equip_model
end

function ItemWearable:get_bodygroups(player)
  return self.equip_bodygroups
end

function ItemWearable:get_valid_models()
  return self.valid_models
end

function ItemWearable:can_equip(player)
  if self:get_valid_models() and #self:get_valid_models() > 0 then
    for k, v in pairs(self:get_valid_models()) do
      if v:lower() == player:GetModel():lower() then
        return true
      end
    end
  else
    return true
  end

  return false
end

function ItemWearable:post_equipped(player)
  if self:get_equip_model(player) then
    self:set_data('native_model', player:GetModel())
    player:SetModel(self:get_equip_model(player))
  end

  if self:get_bodygroups(player) then
    local bodygroup_data = player:GetBodyGroups()
    local native_bodygroups = {}

    for k, v in pairs(self:get_bodygroups(player)) do
      if isstring(k) then
        for k1, v1 in pairs(bodygroup_data) do
          if k == v1.name then
            native_bodygroups[v1.id] = player:GetBodygroup(v1.id)
            player:SetBodygroup(v1.id, v)
          end
        end
      else
        native_bodygroups[k] = player:GetBodygroup(k)
        player:SetBodygroup(k, v)
      end
    end

    self:set_data('native_bodygroups', native_bodygroups)
  end
end

function ItemWearable:post_unequipped(player)
  if self:get_equip_model(player) then
    player:SetModel(self:get_data('native_model'))
  end

  if self:get_bodygroups(player) then
    local native_bodygroups = self:get_data('native_bodygroups')

    if native_bodygroups and #native_bodygroups > 0 then
      player:set_bodygroups(native_bodygroups)
    end
  end

  for k, v in pairs(player:get_items(self.equip_inv)) do
    local item_table = Item.find_instance_by_id(v)

    if self.instance_id == v then continue end

    if item_table and !item_table:can_equip(player) then
      item_table:on_use(player)
    end
  end
end
