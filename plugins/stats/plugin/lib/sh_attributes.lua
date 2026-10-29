--- Registry of the attribute definitions. The player methods that read and change the
-- attributes of a player's character are in `lib/meta`.
-- Definitions are `AttributeBase` objects registered with `Attributes.register`, usually
-- by `Attributes.include_attributes` loading the files of a plugin's `attributes` folder.
-- This file adds `attributes` to the extra folders of every plugin and handles that folder
-- through the PluginIncludeFolder hook. It is part of the lib folder of the Stats plugin,
-- which Flux includes before the other folders of the plugin and before its sh_plugin.lua, so
-- the attributes folder of the Stats plugin is loaded this way too, as are those of the
-- plugins and the schema that load after it.
--
-- What a character has of an attribute is kept in an `Attribute` record: a level and any
-- number of boosts. A level changes only when it is set, by staff or by the code of a
-- plugin, such as the Levels plugin spending a point on it. A boost may carry an identifier,
-- which lets the code that gave it replace or remove it later, and may have no expiry, in
-- which case it stays until it is removed. The server networks the attributes of a player to
-- that player alone, in the private 'attributes' networked variable, which the getters read
-- on the client.

mod 'Attributes'

local tonumber = tonumber
local math_clamp = math.clamp

local stored = Attributes.stored or {}
Attributes.stored = stored

--- Returns every registered attribute definition.
-- @return [Map attribute definitions keyed by attribute ID]
function Attributes.get_stored()
  return stored
end

--- Returns the definition of a registered attribute.
-- @param id [String attribute ID]
-- @return [AttributeBase the attribute definition, or nil if it is not registered]
function Attributes.find(id)
  return stored[id]
end

--- Stores an attribute definition and runs the AttributeRegistered hook. Missing fields get
-- defaults: min 0, max 10 and default equal to min.
-- ```
-- local attribute = AttributeBase.new('sanity')
-- attribute.name = 'attribute.sanity.name'
-- attribute.boostable = false
--
-- Attributes.register(attribute.attribute_id, attribute)
-- ```
-- @param id [String unique attribute ID; raises an error when it is not a string]
-- @param data [AttributeBase attribute definition; nothing happens when it is nil]
-- @see [AttributeBase#register]
function Attributes.register(id, data)
  if !data then return end

  if !isstring(id) then
    error_with_traceback('Attempt to register an attribute without a valid ID!')

    return
  end

  data.name = data.name or 'attribute.other.name'
  data.description = data.description or 'attribute.other.desc'
  data.max = data.max or 10
  data.min = data.min or 0
  data.default = math_clamp(tonumber(data.default) or data.min, data.min, data.max)
  data.category = data.category or 'attribute.category.other'

  --- Called on both realms when an attribute definition is registered, after its missing
  -- fields have been given their defaults and before it is stored. A handler may change the
  -- definition.
  -- @param id [String Attribute ID]
  -- @param data [AttributeBase The attribute definition]
  hook.Run('AttributeRegistered', id, data)

  stored[id] = data
end

--- Includes every file of a folder as an attribute definition. Each file gets a fresh ATTRIBUTE
-- global, an AttributeBase named after the file, that is registered once the file has run.
-- ```
-- -- attributes/sh_strength.lua, registered as 'strength'
-- ATTRIBUTE.name = 'attribute.strength.name'
-- ATTRIBUTE.max = 20
-- ```
-- @param directory [String folder to include files from]
function Attributes.include_attributes(directory)
  Pipeline.include_folder('attribute', directory)
end

--- Adds up the boosts in the data of an attribute. If the attribute has boost_limited set,
-- the sum is cut down so that the level together with the boosts stays between the
-- attribute's min and max.
-- @param attribute_table [AttributeBase attribute definition]
-- @param attribute [Map data of the attribute as `Player:get_attribute_data` returns it;
--   its level and boosts are used]
-- @return [Number]
function Attributes.sum_boosts(attribute_table, attribute)
  local boost = 0
  local boosts = attribute.boosts

  if boosts then
    for _, boost_data in pairs(boosts) do
      boost += tonumber(boost_data.value) or 0
    end
  end

  if attribute_table.boost_limited then
    local level = attribute.level or attribute_table.default

    boost = math_clamp(level + boost, attribute_table.min, attribute_table.max) - level
  end

  return boost
end

--- Checks whether an attribute is shown to a player on the character sheet. An attribute
-- with its hidden field set is never shown; any other can be hidden with the
-- ShouldShowAttribute hook.
-- @param attribute [AttributeBase attribute definition]
-- @param target [Player player whose attributes are being shown]
-- @return [Boolean]
function Attributes.is_visible(attribute, target)
  if !attribute or attribute.hidden then return false end

  --- Lets plugins hide an attribute from a player, for example one that the faction of the
  -- player has no use for. Called on the client for every registered attribute that does
  -- not have its hidden field set, when the tab menu is opened and twice a second while the
  -- character sheet is open, so that the sheet follows a changed answer.
  -- @param target [Player The player whose attributes are being shown, the local player]
  -- @param attribute [AttributeBase The attribute definition]
  -- @return [Boolean Return false to hide the attribute]
  return hook.Run('ShouldShowAttribute', target, attribute) != false
end

Pipeline.register('attribute', function(id, file_name, _pipe)
  ATTRIBUTE = AttributeBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ATTRIBUTE = nil return end

  ATTRIBUTE:register()
  ATTRIBUTE = nil
end)

--- Hook handlers of the attribute registry, registered as `Attributes` while this file is
-- included, before the Stats plugin itself is registered, so that they already handle the
-- folders of the Stats plugin. The handlers registered under that ID by an earlier
-- inclusion of the file are removed first, so they are never registered twice.
local hooks = {}

--- Includes a plugin's attributes folder when the 'attributes' extra is being loaded.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function hooks:PluginIncludeFolder(extra, folder)
  if extra == 'attributes' then
    Attributes.include_attributes(folder..'/attributes')

    return true
  end
end

Plugin.remove_hooks('Attributes')
Plugin.add_hooks('Attributes', hooks)
Plugin.add_extra('attributes')
