--- Classes gives every faction a set of classes that its members hold, and pays wages by class.
-- A class is a `CharacterClass` object, normally defined in a file of the classes folder of a
-- schema or plugin. It belongs to one faction and sets a name, a description and a color, and
-- optionally a model that replaces the model of its members, a limit of players that may hold
-- it at once, a wage, the weapons its members spawn with, and whether players may pick it
-- themselves. The class of a character is stored in the database; a character without a class
-- gets the class named by the default_class field of its faction. The team of a player stays
-- that of their faction.
--
-- Players switch between the classes of their faction in the Classes tab of the tab menu, no
-- more often than the `class_change_cooldown` config allows, and staff set classes with the
-- SetClass command. Every `wages_interval` seconds each living player is paid the wage of
-- their class, when the Currencies plugin is loaded.
--
-- The `Classes` functions register and look up classes, and the `Player` extensions read and
-- change the class of a player. The `PlayerCanChangeClass` hook can refuse a switch,
-- `GetClassLimit` and `PlayerCanBypassClassLimit` adjust the limits, `OnPlayerClassChanged`
-- reports changes, and `AdjustPlayerWage`, `CanPlayerEarnWage` and `PlayerEarnedWage` take
-- part in the payment of wages.

PLUGIN:set_global('Classes')

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Loads the classes folder of a plugin or of the schema as class definitions. The folder
-- is one of the default extras, so the plugin takes it over rather than adding an extra of
-- its own.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function Classes:PluginIncludeFolder(extra, folder)
  if extra == 'classes' then
    self.include_classes(folder..'/classes/')

    return true
  end
end
