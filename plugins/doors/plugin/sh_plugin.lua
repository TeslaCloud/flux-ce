--- Doors makes the doors of a map configurable and lockable.
-- A door has properties, such as its name, title type, skin and lock state, that are edited in
-- the door menu by staff with the 'manage_doors' permission and saved for the map, and a tree
-- of conditions of the Conditions plugin that decides which players may lock and unlock it. A
-- player opens the menu of the door they look at with the ShowSpare1 key (F3 by default);
-- those who may lock the door toggle its lock from that menu or by using the door while
-- sprinting. The title of a door is drawn on the door by its title type.
--
-- Plugins add properties with `Doors:register_property` from the `RegisterDoorProperties` hook
-- and title types with `Doors:register_title_type` from `RegisterDoorTitleTypes`.
-- `PlayerCanLockDoor` grants the right to lock a door, `PlayerUseDoor` reports that a door is
-- used, and `InitialDoorsLoad` lets a schema set the doors up on a map that has no saved door
-- data.

PLUGIN:set_global('Doors')

local properties = Doors.properties or {}
local title_types = Doors.title_types or {}
Doors.properties = properties
Doors.title_types = title_types

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
-- @param data [Map property definition: get_save_data(entity), on_load(entity, data)
--   and the optional create_panel(entity, panel)]
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

require_relative 'sh_config'
require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

--- Registers the 'manage_doors' level design permission.
function Doors:RegisterPermissions()
  Bolt:register_permission(
    'manage_doors',
    'Doors settings access',
    'Grants access to customize doors.',
    'permission.categories.level_design',
    'assistant'
  )
end

--- Runs the RegisterDoorProperties and RegisterDoorTitleTypes hooks so that plugins can
-- register their door properties and title types.
function Doors:OnPluginsLoaded()
  --- Lets plugins register their door properties with `Doors:register_property`. Called on the
  -- server and the client once all plugins have been loaded.
  hook.Run('RegisterDoorProperties')
  --- Lets plugins register their door title types with `Doors:register_title_type`. Called on
  -- the server and the client once all plugins have been loaded.
  hook.Run('RegisterDoorTitleTypes')
end
