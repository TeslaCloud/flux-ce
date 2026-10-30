--- Doors makes the doors of a map configurable, lockable and ownable.
-- A door has properties, such as its name, title type, skin and lock state, that are edited in
-- the door menu by staff with the 'manage_doors' permission and saved for the map, and a tree
-- of conditions of the Conditions package that decides which players may lock and unlock it. A
-- player opens the menu of the door they look at with the ShowSpare1 key (F3 by default);
-- those who may lock the door toggle its lock from that menu or by using the door while
-- sprinting. The title of a door is drawn on the door by its title type.
--
-- Staff can mark a door as ownable, optionally with a price of its own. A character buys such
-- a door from the door menu, paying through the Currencies plugin when it is loaded, and may
-- sell it back for a share of what was paid. The owner locks and unlocks the door, sets a
-- second line of text on it and gives other characters access at two levels: to lock and
-- unlock it (`DOOR_ACCESS_USE`), or to also change its text and the access of others
-- (`DOOR_ACCESS_MANAGE`). Ownership belongs to the character, is saved with the doors of the
-- map and ends when the character is deleted. Doors that staff link into a group with the
-- Door Link tool are bought, shared and labeled together. Nothing of this applies to a door
-- until staff make it ownable, and ownership needs the Characters plugin.
--
-- Plugins add properties with `Doors:register_property` from the `RegisterDoorProperties` hook
-- and title types with `Doors:register_title_type` from `RegisterDoorTitleTypes`.
-- `PlayerCanLockDoor` grants the right to lock a door, `PlayerUseDoor` reports that a door is
-- used, and `InitialDoorsLoad` lets a schema set the doors up on a map that has no saved door
-- data. `PlayerCanBuyDoor`, `PlayerCanSellDoor` and `PlayerCanChangeDoorAccess` can refuse
-- what players do with ownable doors, `DoorOwnerChanged` and `DoorAccessChanged` report
-- the changes, and `GetDoorAccessName` names the characters on the access list of a door.

PLUGIN:set_global('Doors')

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

--- Registers the 'manage_doors' level design permission.
function Doors:RegisterPermissions()
  Bolt:register_permission('manage_doors', nil, nil, 'permission.categories.level_design')
end

--- Runs the RegisterDoorProperties and RegisterDoorTitleTypes hooks so that plugins can
-- register their door properties and title types.
function Doors:PluginsLoaded()
  --- Lets plugins register their door properties with `Doors:register_property`. Called on the
  -- server and the client once all plugins have been loaded.
  hook.Run('RegisterDoorProperties')
  --- Lets plugins register their door title types with `Doors:register_title_type`. Called on
  -- the server and the client once all plugins have been loaded.
  hook.Run('RegisterDoorTitleTypes')
end
