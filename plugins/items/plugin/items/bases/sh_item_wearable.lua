if !ItemEquipable then
  require_relative 'sh_item_equipable'
end

class 'ItemWearable' extends 'ItemEquipable'

ItemWearable.name = 'Clothing Base'
ItemWearable.description = 'Clothes that can be equipped.'
ItemWearable.category = 'item.category.clothing'
ItemWearable.equip_inv = 'equipment_torso'
ItemWearable.equip_slot = 'item.slot.chest'
ItemWearable.background_color = Color(50, 150, 50)

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
    return self:get_equip_model(PLAYER) or self:get_model()
  end
end

function ItemWearable:get_model_by_group(player)
  if self.model_group then
    local player_model = player:GetModel():lower()
    local path = player_model:GetPathFromFilename()

    return player_model:gsub(path:match('(%a+)/$'), self.model_group)
  end
end

function ItemWearable:get_equip_model(player)
  return self:get_model_by_group(player) or self.equip_model
end

function ItemWearable:get_bodygroups(player)
  return self.equip_bodygroups
end

function ItemWearable:get_valid_models()
  return self.valid_models
end

function ItemWearable:get_valid_model_group()
  return self.valid_model_group
end

function ItemWearable:can_equip(player)
  local valid_models = self:get_valid_models()
  local valid_model_group = self:get_valid_model_group()
  local player_model = player:GetModel():lower()

  if valid_models then
    for k, v in pairs(valid_models) do
      if v:lower() == player_model then
        return true
      end
    end

    return false
  end

  if valid_model_group then
    if player_model:find(valid_model_group) then
      return true
    end

    return false
  end

  return true
end

function ItemWearable:post_equipped(player)
  local model = self:get_equip_model(player)

  if model then
    self:set_data('native_model', player:GetModel())
    player:SetModel(model)
  end

  local bodygroups = self:get_bodygroups(player)

  if bodygroups then
    local bodygroup_data = player:GetBodyGroups()
    local native_bodygroups = {}

    for k, v in pairs(bodygroups) do
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
    if self.instance_id == v then continue end

    if v:can_equip(player) == false then
      v:on_use(player)
    end
  end
end
