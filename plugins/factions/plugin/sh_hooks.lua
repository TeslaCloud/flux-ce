--- Shared hooks of the Factions plugin: the options of character creation that start a
-- character as a member of a faction.

--- Puts the look of a faction on a creation option and makes the option start the character
-- as a member of the faction.
-- @param option [Map the creation option, changed in place]
-- @param faction_table [Faction]
local function label_option(option, faction_table)
  option.name = faction_table:get_name()
  option.description = faction_table:get_description()
  option.image = faction_table:get_image()
  option.sounds = faction_table.menu_sound
  option.color = faction_table:get_color()
  option.data.faction = faction_table.faction_id
end

--- Returns the position right after the last option of a species, where the options of the
-- whitelisted factions of that species go.
-- @param options [List<Map>]
-- @param species_id [String]
-- @return [Number index to insert at; after the last option when the species has none]
local function insert_position(options, species_id)
  for index = #options, 1, -1 do
    if options[index].species == species_id then
      return index + 1
    end
  end

  return #options + 1
end

--- Brings the options of character creation in line with the factions. The option of a species
-- whose default faction is registered is labeled with that faction and starts the character
-- as its member; it is removed when that faction is whitelisted and the actor neither has its
-- whitelist nor may bypass the limits of creation (see `Characters.can_bypass_creation_limits`).
-- Every other whitelisted faction the actor has a whitelist for, or every one for an actor who
-- may bypass the limits, gets an option of its own with the ID '<species>:<faction>', right
-- after the options of its species, which starts the character with the kit of the faction.
-- A faction that is neither the default of its species nor whitelisted is joined through its
-- items only.
-- @param actor [Player the player who creates the character]
-- @param options [List<Map> the creation options, changed in place]
-- @param extra_data [Map creation data on the server; on the client the extra data of the
--   creation screen, nil when it has none]
function Factions:AdjustCharacterCreationOptions(actor, options, extra_data)
  local bypass = Characters.can_bypass_creation_limits(actor, extra_data)

  for index = #options, 1, -1 do
    local option = options[index]
    local faction_table = self.get_default_faction(Species.find_by_id(option.species))

    if faction_table then
      if faction_table.whitelisted and !bypass and !actor:has_whitelist(faction_table.faction_id) then
        table.remove(options, index)
      else
        label_option(option, faction_table)
      end
    end
  end

  for _, faction_table in ipairs(self.get_list()) do
    local species = faction_table:get_species()

    if faction_table.whitelisted and species and self.get_default_faction(species) != faction_table
    and (bypass or actor:has_whitelist(faction_table.faction_id)) then
      local option = {
        id = faction_table.species..':'..faction_table.faction_id,
        species = faction_table.species,
        data = {}
      }

      label_option(option, faction_table)

      table.insert(options, insert_position(options, faction_table.species), option)
    end
  end
end
