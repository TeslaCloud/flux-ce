--- ItemWearable is the base class for clothing: items that change the model or the
-- bodygroups of the player while equipped.
-- A derived item sets `equip_inv` (`'equipment_torso'` by default) and `equip_slot`, and
-- says what it changes. The model the player gets is, in this order: their current model
-- with the last folder of its path replaced by `model_group`, or `equip_model`, or the
-- `model` of the item itself. `equip_bodygroups` maps bodygroup ids or names to the
-- values they are set to. `valid_models`, a list of model paths, or `valid_model_group`,
-- a pattern that the path of the player's model has to contain, restrict who can wear the
-- item. The model and the bodygroups the player had before are kept in the data of the
-- item and given back when it is unequipped. `equip_model_classes` maps 'male', 'female' and
-- 'universal' to the animation classes of the models that `model_group` dresses wearers in
-- (see `ItemWearable:assign_model_classes`).

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

if CLIENT then
  --- Returns the model that is shown in inventory slots: the one the item would put
  -- on the local player, or the item's own model if there is none. Client-side only.
  -- @return [String path to the model]
  function ItemWearable:get_icon_model()
    return self:get_equip_model(PLAYER) or self:get_model()
  end
end

--- Returns a model path with the letters at the end of its last folder replaced by a model
-- group, wherever they appear in the path.
-- @param model_path [String]
-- @param model_group [String]
-- @return [String path to the model in lower case, Number amount of replacements made; nil if
--   the last folder of the path does not end in a letter]
local function model_in_group(model_path, model_group)
  local lowered = model_path:lower()
  local matched = lowered:GetPathFromFilename():match('(%a+)/$')

  if matched then
    return lowered:gsub(matched, model_group)
  end
end

--- Builds the model for the player to wear by replacing the last folder
-- in the path of their current model with the item's model_group.
-- @param owner [Player]
-- @return [String path to the model, Number amount of replacements made;
--   nil if the item has no model_group or the model is not inside of a suitable folder]
function ItemWearable:get_model_by_group(owner)
  if self.model_group then
    return model_in_group(owner:GetModel(), self.model_group)
  end
end

--- Returns the model that the player gets when they equip the item.
-- @param owner [Player]
-- @return [String path to the model; the item's own model if it has no other one]
function ItemWearable:get_equip_model(owner)
  return self:get_model_by_group(owner) or self.equip_model or self.model
end

--- Returns the bodygroups that the player gets when they equip the item.
-- @param _owner [Player]
-- @return [Map bodygroup id (Number) or bodygroup name (String) to its value,
--   or nil if the item does not change bodygroups]
function ItemWearable:get_bodygroups(_owner)
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

--- Checks whether a model is able to wear the item: it has to be one of valid_models, or
-- contain valid_model_group, when the item sets them.
-- @param model_path [String path to the model]
-- @return [Boolean]
function ItemWearable:fits_model(model_path)
  local valid_models = self:get_valid_models()
  local valid_model_group = self:get_valid_model_group()
  local lowered = model_path:lower()

  if valid_models then
    for _, model in pairs(valid_models) do
      if model:lower() == lowered then
        return true
      end
    end

    return false
  end

  if valid_model_group then
    return lowered:find(valid_model_group) != nil
  end

  return true
end

--- Called by ItemEquipable:can_transfer before the item is equipped.
-- Checks whether the model of the player is able to wear the item.
-- @param owner [Player the player who is about to wear the item]
-- @return [Boolean]
function ItemWearable:can_equip(owner)
  return self:fits_model(owner:GetModel())
end

--- Assigns the animation classes of equip_model_classes to the models that the model_group of
-- the item dresses its wearers in (see `Flux.Anim:set_model_class`): every model of every
-- registered species that is able to wear the item (see `ItemWearable:fits_model`) gets the
-- class of the key of the species' model list it is in ('male', 'female' or 'universal'),
-- falling back to the 'universal' class, for its counterpart in the model group. The Items
-- plugin calls it for every item on both realms once all plugins, and with them all species,
-- have been loaded.
-- ```
-- ITEM.model_group = 'police'
-- ITEM.equip_model_classes = { male = 'metrocop', female = 'female' }
-- ```
function ItemWearable:assign_model_classes()
  local model_classes = self.equip_model_classes
  local model_group = self.model_group

  if !istable(model_classes) or !isstring(model_group) then return end

  for _, species in ipairs(Species.get_list()) do
    for gender, models in pairs(species:get_models()) do
      local model_class = model_classes[gender] or model_classes.universal

      if isstring(model_class) and istable(models) then
        for _, model_path in ipairs(models) do
          local group_model = self:fits_model(model_path) and model_in_group(model_path, model_group)

          if group_model then
            Flux.Anim:set_model_class(group_model, model_class)
          end
        end
      end
    end
  end
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

    for bodygroup, value in pairs(bodygroups) do
      if isstring(bodygroup) then
        for _, group_info in pairs(bodygroup_data) do
          if bodygroup == group_info.name then
            native_bodygroups[group_info.id] = owner:GetBodygroup(group_info.id)
            owner:SetBodygroup(group_info.id, value)
          end
        end
      else
        native_bodygroups[bodygroup] = owner:GetBodygroup(bodygroup)
        owner:SetBodygroup(bodygroup, value)
      end
    end

    self:set_data('native_bodygroups', native_bodygroups)
  end
end

--- Called when the item gets unequipped. Gives the player their model and bodygroups back,
-- those that the item has stored when it was equipped.
-- @param owner [Player]
function ItemWearable:post_unequipped(owner)
  local native_model = self:get_data('native_model')

  if native_model and self:get_equip_model(owner) then
    owner:SetModel(native_model)
  end

  if self:get_bodygroups(owner) then
    local native_bodygroups = self:get_data('native_bodygroups')

    if istable(native_bodygroups) and next(native_bodygroups) != nil then
      owner:set_bodygroups(native_bodygroups)
    end
  end
end
