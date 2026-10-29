--- Shared core of the Doors plugin: the access levels of characters to owned doors, the
-- registries of door properties and title types, and what both realms know about the
-- ownership of a door. Plugins add properties with `Doors:register_property` from the
-- `RegisterDoorProperties` hook and title types with `Doors:register_title_type` from
-- `RegisterDoorTitleTypes`.

if !Doors then
  PLUGIN:set_global('Doors')
end

--- Access levels of a character to an owned door. A character without access has
-- `DOOR_ACCESS_NONE`. `DOOR_ACCESS_USE` lets it lock and unlock the door,
-- `DOOR_ACCESS_MANAGE` also lets it change the text of the door and give or take the
-- `DOOR_ACCESS_USE` level, and `DOOR_ACCESS_OWNER` is the level of the owner, who alone
-- gives and takes `DOOR_ACCESS_MANAGE` and sells the door.
DOOR_ACCESS_NONE    = 0
DOOR_ACCESS_USE     = 1
DOOR_ACCESS_MANAGE  = 2
DOOR_ACCESS_OWNER   = 3

local properties = Doors.properties or {}
local title_types = Doors.title_types or {}
Doors.properties = properties
Doors.title_types = title_types

--- How far from a door (in units, from the eyes of the player to the nearest point of the
-- door, see `Player:is_in_reach`) a player can open its menu, lock or unlock it, buy, sell
-- and manage it and, for staff, edit its settings. A schema may change it. The longest
-- text an owner can put on a door and how many characters can have access to one door are
-- the door_text_length and door_access_entries configs.
Doors.use_distance = Doors.use_distance or 160

--- The title type that draws the status of ownable doors that have never been given a
-- title type. A schema may change it.
Doors.default_title_type = Doors.default_title_type or 'center'

--- Registers a door property that is saved together with the door
-- and can optionally be edited in the door menu.
-- ```
-- Doors:register_property('name', {
--   -- Returns the value to save. Also provides the value displayed in the door menu.
--   get_save_data = function(entity)
--     return entity:get_nv('fl_name', '')
--   end,
--   -- Serverside. Applies a value that was loaded or changed in the door menu.
--   on_load = function(entity, data)
--     entity:set_nv('fl_name', data)
--   end,
--   -- Optional, clientside. Creates and returns the row for the door menu.
--   create_panel = function(entity, panel)
--     local name = panel.properties:CreateRow(t'door.categories.general', t'door.properties.name')
--     name:Setup('Generic')
--
--     return name
--   end
-- })
-- ```
-- @param id [String unique property id, also the key the value is saved under]
-- @param data [Map property definition: the optional get_save_data(entity),
--   on_load(entity, data) and create_panel(entity, panel); a property without
--   get_save_data is not saved]
function Doors:register_property(id, data)
  properties[id] = data
end

--- Registers a way to draw the title of a door, selectable in the door menu.
-- ```
-- Doors:register_title_type('plain', {
--   name = 'door.title_type.plain',
--   -- Called in a 3D2D context that is centered on a face of the door.
--   draw = function(entity, w, h, alpha)
--     local text = entity:get_nv('fl_name')
--     local font = Theme.get_font('text_3d2d')
--     local text_w, text_h = util.text_size(text, font)
--
--     draw.SimpleText(text, font, -text_w / 2, -h / 4 - text_h / 2, color_white:alpha(alpha))
--   end
--   -- An optional draw_back function with the same arguments draws the back face.
-- })
-- ```
-- @param id [String unique title type id]
-- @param data [Map title type definition: name (phrase), draw(entity, w, h, alpha)
--   and the optional draw_back(entity, w, h, alpha)]
function Doors:register_title_type(id, data)
  title_types[id] = data
end

--- Checks whether staff have marked a door, or the group it is linked into, as ownable.
-- @param entity [Entity the door]
-- @return [Boolean]
function Doors:is_ownable(entity)
  return entity:get_nv('fl_door_ownable', false)
end

--- Returns the ID of the character that owns a door.
-- @param entity [Entity the door]
-- @return [Number character ID, or nil if nobody owns the door]
function Doors:get_owner_id(entity)
  return entity:get_nv('fl_door_owner')
end

--- Checks whether a door has an owner.
-- @param entity [Entity the door]
-- @return [Boolean]
function Doors:is_owned(entity)
  return entity:get_nv('fl_door_owner') != nil
end

--- Returns the text that the owner of a door has put on it.
-- @param entity [Entity the door]
-- @return [String the text, or an empty string if there is none]
function Doors:get_text(entity)
  return entity:get_nv('fl_door_text', '')
end

--- Returns the ID of the active character of a player, which is what owns doors and holds
-- access to them.
-- @param actor [Player]
-- @return [Number character ID; nil for bots, for players without an active character and
--   when the Characters plugin is not loaded]
function Doors:get_character_id(actor)
  if !Characters or !IsValid(actor) or actor:IsBot() or !actor:is_character_loaded() then return end

  return tonumber(actor:get_character_id())
end

--- Checks whether the active character of a player owns a door.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean]
function Doors:is_owner(actor, entity)
  local character_id = self:get_character_id(actor)

  return character_id != nil and character_id == self:get_owner_id(entity)
end

--- Returns what a door costs: its own price if staff have set one, the door_price config
-- otherwise, rounded to the decimals of the default currency of the Currencies plugin. A
-- group of linked doors has one price for all of its doors. Doors are free while the
-- Currencies plugin is not loaded or has no default currency.
-- @param entity [Entity the door]
-- @return [Number the price, 0 if the door is free, String ID of the currency the price is
--   in, nil if there is no currency to pay with]
function Doors:get_price(entity)
  local currency = Currencies and Currencies:get_default_currency()

  if !currency then return 0 end

  local currency_data = Currencies:find_currency(currency)
  local price = tonumber(entity:get_nv('fl_door_price')) or tonumber(Config.get('door_price')) or 0

  return math.round(math.max(price, 0), currency_data.decimals or 0), currency
end
