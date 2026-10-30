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
-- character, `ActiveCharacterSet` and `PostCharacterLoaded` tell them that a character has
-- been loaded, and `AddCharacterCreationMenuStages` and `AddMainMenuItems` add stages to the
-- character creation screen and buttons to the main menu. `GetCharacterLimit` changes the
-- limit for a player, and `PlayerCanUseCharacter`, `PlayerCanSwitchCharacter` and
-- `PlayerCanDeleteCharacter` can refuse a request to load or delete a character with a
-- reason. `PlayerNeedsCharacter` lets a player stay in the world without a character,
-- `GetCharacterOwner` gives a new character to another user record than its creator's, and
-- `Characters.activate` and `Player:clear_active_character` let a player play a character of
-- another record and drop it again, which runs `ActiveCharacterCleared`. A plugin that only
-- needs to remember something about a character can keep it in the generic character data
-- (`Player:set_character_data`) instead of adding a column.

PLUGIN:set_global('Characters')

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

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
