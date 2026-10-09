--- A class that characters can hold within a faction, such as a job or a division.
-- It holds the name, description and color of the class, the ID of the faction it belongs
-- to, an optional model that replaces the model of its members, the limit of players that
-- may hold it at once, the wage it pays, the weapons its members spawn with, and whether
-- players may pick it themselves. Classes are normally defined in the files of a classes
-- folder, where the object is available as CLASS (see `Classes.include_classes`), and are
-- registered with `CharacterClass:register`. A definition can override
-- `CharacterClass:on_player_join` and `CharacterClass:on_player_leave`. This is a plain class
-- that is not stored in the database: a character only stores the ID of its class.

class 'CharacterClass'

--- Creates a class with default settings: no faction, no model, no limit, no wage, an empty
-- loadout, and open for players to pick. Fields are left unset when no ID is given.
-- ```
-- local officer = CharacterClass.new('officer')
-- officer.name = 'Officer'
-- officer.description = 'Leads a patrol team.'
-- officer.faction = 'police'
-- officer.limit = 4
-- officer.wage = 40
-- officer.loadout = { 'weapon_stunstick', 'weapon_pistol' }
-- officer:register()
-- ```
-- @param id [String class ID, normalized with to_id]
function CharacterClass:init(id)
  if !id then return end

  self.class_id = id:to_id()
  self.name = 'Unknown Class'
  self.description = 'This class has no description set!'
  self.faction = nil
  self.color = nil
  self.model = nil
  self.limit = 0
  self.wage = 0
  self.loadout = {}
  self.selectable = true
  self.priority = 0
end

--- Returns the name of the class.
-- @return [String name or its language phrase]
function CharacterClass:get_name()
  return self.name
end

--- Returns the description of the class.
-- @return [String description or its language phrase]
function CharacterClass:get_description()
  return self.description
end

--- Returns the faction the class belongs to.
-- @return [Faction the faction, or nil if no faction is registered under the class's faction ID]
function CharacterClass:get_faction()
  return Factions.find_by_id(self.faction)
end

--- Returns the color of the class: its own color, or else the color of its faction.
-- @return [Color white when neither the class nor its faction has a color]
function CharacterClass:get_color()
  if self.color then
    return self.color
  end

  local faction_table = self:get_faction()

  return faction_table and faction_table.color or Color(255, 255, 255)
end

--- Returns the model that members of the class use instead of the model of their character.
-- The model field of a class is either a single path, or a table of paths keyed by 'male',
-- 'female', 'no_gender' and 'universal', the last one being the fallback for a gender that
-- has no path of its own.
-- ```
-- CLASS.model = 'models/police.mdl'
--
-- CLASS.model = {
--   male = 'models/police_male.mdl',
--   female = 'models/police_female.mdl'
-- }
-- ```
-- @param target [Player the member the model is for; needs an active character]
-- @return [String model path, or nil if the class does not change the model of that player]
function CharacterClass:get_model(target)
  local model = self.model

  if istable(model) then
    model = model[target:get_gender()] or model.universal
  end

  if isstring(model) and model != '' then
    return model
  end
end

--- Returns the wage the class pays every wages interval.
-- @return [Number]
function CharacterClass:get_wage()
  return self.wage
end

--- Returns the weapons that members of the class are given when they spawn, in addition to
-- the default loadout.
-- @return [List<String> weapon classes]
function CharacterClass:get_loadout()
  return self.loadout
end

--- Called on the server when a player is put into this class by `Player:set_class` or by a
-- change of their faction. It is not called when a character is loaded. Does nothing by
-- default; override it in the class definition.
-- @param target [Player]
-- @param old_class [CharacterClass the class the player held before, nil if they had none]
function CharacterClass:on_player_join(target, old_class)
end

--- Called on the server when a player is moved out of this class by `Player:set_class` or by
-- a change of their faction. It is not called when a character is unloaded. Does nothing by
-- default; override it in the class definition.
-- @param target [Player]
-- @param new_class [CharacterClass the class the player holds now, nil if they have none]
function CharacterClass:on_player_leave(target, new_class)
end

--- Registers the class under its class ID.
-- @see [Classes.add_class]
function CharacterClass:register()
  Classes.add_class(self.class_id, self)
end
