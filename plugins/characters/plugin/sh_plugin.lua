--- Characters lets every player own several characters and play one of them at a time.
-- A character is a `Character` record that belongs to the player's user record and stores a
-- name, gender, physical description, model and skin, along with the health, armor and
-- reserve ammo its player had when it was last saved. Players create, load and delete their
-- characters in the main menu, which opens after the intro when they join; until a character
-- is loaded the player stays hidden and dead and the HUD is not drawn. The `Characters`
-- functions create, save, delete, ban and edit characters on the server, and the `Player`
-- extensions return a player's characters and the fields of the active one.
--
-- A player may have as many characters as the `characters_limit` config allows, and a name
-- that a player picks has to be unlike the name of any other character. Staff can ban a
-- character with `/charban add`: it can then be neither loaded nor deleted until
-- `/charban remove` lifts the ban. Players change their own description with CharPhysDesc.
--
-- Other plugins build on it through hooks: `PlayerCreateCharacter` validates the data of a new
-- character, `PostCreateCharacter` and `SaveCharacterData` let them keep their own fields on a
-- character, `ActiveCharacterSet` and `PostLoadCharacter` tell them that a character has
-- been loaded, `AdjustCharacterPreloads` names the relations that are loaded with the
-- characters of a player, and `AddCharacterCreationMenuStages` and `AddMainMenuItems` add
-- stages to the character creation screen and buttons to the main menu. `GetCharacterLimit`
-- changes the limit for a player, and `PlayerCanUseCharacter`, `PlayerCanSwitchCharacter` and
-- `PlayerCanDeleteCharacter` can refuse a request to load or delete a character with a
-- reason. `PlayerNeedsCharacter` lets a player stay in the world without a character,
-- `GetCharacterOwner` gives a new character to another user record than its creator's, and
-- `Characters.activate` and `Player:clear_active_character` let a player play a character of
-- another record and drop it again, which runs `ActiveCharacterCleared`. A plugin that only
-- needs to remember something about a character can keep it in the generic character data
-- (`Player:set_character_data`) instead of adding a column.
--
-- Every character has a species, what the character is: a `Species` defined in a file of the
-- `species` folder of a plugin or of the schema, which this plugin includes for all of them.
-- The species owns the models of its characters, whether they have a gender, a name and a
-- description of their own, their random names and how many characters of it one player may
-- have. The first stage of character creation offers the options that
-- `Characters.get_creation_options` builds, one per species unless an
-- `AdjustCharacterCreationOptions` handler changes the list, and is left out when there is
-- only one. `PlayerCanBypassCreationLimits` lifts the limit of characters per species.
--
-- The real name of a character is the public `name` networked variable of its player. A
-- `GetCharacterDisplayName` handler can give it another name to be shown under, which
-- `Characters.refresh_display_name` networks as `display_name`, which `Player:name` then
-- returns on both realms and which commands accept besides the character name, as the public
-- name of the player (see `Player:get_public_name`); the `model` argument type of commands
-- completes the models of the species of the targets.

PLUGIN:set_global('Characters')

--- Returns the species of the players that a command argument names (see
-- `Flux.Command:find_argument_players`). Every registered species is returned when the
-- argument names nobody with a species.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param target_arg [String the typed player argument]
-- @return [List<Species>]
local function suggested_species(actor, target_arg)
  local targets = Flux.Command:find_argument_players(actor, target_arg)
  local found, seen = {}, {}

  for _, target in ipairs(targets) do
    local species = target:get_species()

    if species and !seen[species] then
      seen[species] = true
      found[#found + 1] = species
    end
  end

  return #found > 0 ? found : Species.get_list()
end

--- Completes arguments of the 'model' type with the models of the species of the players
-- named by the first argument, or of every species.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param _partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments typed before the completed one]
-- @return [List<String> model paths]
local function complete_model(actor, _partial, args)
  local values = {}

  for _, species in ipairs(suggested_species(actor, isstring(args[1]) and args[1] or '')) do
    for _, models in SortedPairs(species:get_models()) do
      for _, model_path in ipairs(istable(models) and models or {}) do
        values[#values + 1] = model_path
      end
    end
  end

  return values
end

Flux.Command:add_completer('model', complete_model)

require_relative 'cl_hooks'
require_relative 'sh_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Registers the 'species' plugin folder and includes the species that come with this
-- plugin.
function Characters:OnPluginLoaded()
  Plugin.add_extra('species')

  Species.include_species(self:get_folder()..'/species/')
end

--- Includes the species of a plugin when its 'species' folder is being included.
-- @param extra [String name of the folder being included]
-- @param folder [String path to the plugin's folder]
-- @return [Boolean true if the folder was handled here, nil otherwise]
function Characters:PluginIncludeFolder(extra, folder)
  if extra == 'species' then
    Species.include_species(folder..'/species/')

    return true
  end
end

--- Registers the 'character' condition, which compares a player's active character ID.
function Characters:RegisterConditions()
  Conditions:register_condition('character', {
    name = 'condition.character.name',
    text = 'condition.character.text',
    get_args = function(panel, _data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local character_id = panel.data.character_id or ''

      return { operator = operator, character = character_id }
    end,
    icon = 'icon16/user.png',
    check = function(target, data)
      if !data.operator or !data.character_id then return false end

      return util.process_operator(data.operator, target:get_character_id(), data.character_id)
    end,
    set_parameters = function(_id, data, panel, _menu, parent)
      parent:create_selector(data.name, 'condition.character.message', 'condition.characters', player.GetAll(),
      function(selector, target)
        if target:is_character_loaded() then
          selector:add_choice(target:name(), function()
            panel.data.character_id = target:get_character_id()

            panel.update()
          end)
        end
      end)
    end,
    set_operator = 'equal'
  })
end
