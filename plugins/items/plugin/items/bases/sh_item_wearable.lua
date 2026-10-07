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
--   ['mask'] = 1 -- Sets the bodygroup named 'mask' to 1
--                -- (only if the model actually has this bodygroup)
-- }

if CLIENT then
  --- Returns the model that is shown in inventory slots: the one the item would put
  -- on the local player, or the item's own model if there is none. Client-side only.
  -- @return [String path to the model]
  function ItemWearable:get_icon_model()
    return self:get_equip_model(PLAYER) or self:get_model()
  end
end

--- Builds the model for the player to wear by replacing the last folder
-- in the path of their current model with the item's model_group.
-- @param owner [Player]
-- @return [String path to the model, Number amount of replacements made;
--   nil if the item has no model_group]
function ItemWearable:get_model_by_group(owner)
  if self.model_group then
    local player_model = owner:GetModel():lower()
    local path = player_model:GetPathFromFilename()

    return player_model:gsub(path:match('(%a+)/$'), self.model_group)
  end
end

--- Returns the model that the player gets when they equip the item.
-- @param owner [Player]
-- @return [String path to the model, or nil if the item does not change the model]
function ItemWearable:get_equip_model(owner)
  return self:get_model_by_group(owner) or self.equip_model
end

--- Returns the bodygroups that the player gets when they equip the item.
-- @param owner [Player]
-- @return [Map bodygroup id (Number) or bodygroup name (String) to its value,
--   or nil if the item does not change bodygroups]
function ItemWearable:get_bodygroups(owner)
  return self.equip_bodygroups
end

--- Returns the player models that are able to wear the item.
-- @return [List<String> paths to the models, or nil if any model fits]
function ItemWearable:get_valid_models()
  return self.valid_models
end

--- Returns the pattern that the player's model has to contain for them to wear the item.
-- @return [String pattern, or nil if any model fits]
function ItemWearable:get_valid_model_group()
  return self.valid_model_group
end

--- Called by ItemEquipable:can_transfer before the item is equipped.
-- Checks whether the model of the player is able to wear the item.
-- @param owner [Player]
-- @return [Boolean]
function ItemWearable:can_equip(owner)
  local valid_models = self:get_valid_models()
  local valid_model_group = self:get_valid_model_group()
  local player_model = owner:GetModel():lower()

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

--- Called when the item gets equipped. Applies the model and the bodygroups of the item
-- to the player, storing the ones they had before in the item's data.
-- @param owner [Player]
function ItemWearable:post_equipped(owner)
  local model = self:get_equip_model(owner)

  if model then
    self:set_data('native_model', owner:GetModel())
    owner:SetModel(model)
  end

  local bodygroups = self:get_bodygroups(owner)

  if bodygroups then
    local bodygroup_data = owner:GetBodyGroups()
    local native_bodygroups = {}

    for k, v in pairs(bodygroups) do
      if isstring(k) then
        for k1, v1 in pairs(bodygroup_data) do
          if k == v1.name then
            native_bodygroups[v1.id] = owner:GetBodygroup(v1.id)
            owner:SetBodygroup(v1.id, v)
          end
        end
      else
        native_bodygroups[k] = owner:GetBodygroup(k)
        owner:SetBodygroup(k, v)
      end
    end

    self:set_data('native_bodygroups', native_bodygroups)
  end
end

--- Called when the item gets unequipped. Gives the player their model and bodygroups back,
-- then calls on_use on the items of the same equipment inventory that no longer fit them.
-- @param owner [Player]
function ItemWearable:post_unequipped(owner)
  if self:get_equip_model(owner) then
    owner:SetModel(self:get_data('native_model'))
  end

  if self:get_bodygroups(owner) then
    local native_bodygroups = self:get_data('native_bodygroups')

    if native_bodygroups and #native_bodygroups > 0 then
      owner:set_bodygroups(native_bodygroups)
    end
  end

  for k, v in pairs(owner:get_items(self.equip_inv)) do
    if self.instance_id == v then continue end

    if v:can_equip(owner) == false then
      v:on_use(owner)
    end
  end
end
