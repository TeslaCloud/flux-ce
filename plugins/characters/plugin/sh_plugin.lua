--- Characters lets every player own several characters and play one of them at a time.
-- A character is a `Character` record that belongs to the player's user record and stores a
-- name, gender, physical description, model, skin and health. Players create, load and delete
-- their characters in the main menu, which opens after the intro when they join; until a
-- character is loaded the player stays hidden and dead and the HUD is not drawn. The
-- `Characters` functions create, save, delete and edit characters on the server, and the
-- `Player` extensions return a player's characters and the fields of the active one.
--
-- Other plugins build on it through hooks: `PlayerCreateCharacter` validates the data of a new
-- character, `PostCreateCharacter` and `SaveCharacterData` let them keep their own fields on a
-- character, `OnActiveCharacterSet` and `PostCharacterLoaded` tell them that a character has
-- been loaded, and `AddCharacterCreationMenuStages` and `AddMainMenuItems` add stages to the
-- character creation screen and buttons to the main menu.

PLUGIN:set_global('Characters')

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
require_relative 'sh_enums'

--- Registers the 'character' condition, which compares a player's active character ID.
function Characters:RegisterConditions()
  Conditions:register_condition('character', {
    name = 'condition.character.name',
    text = 'condition.character.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local character_id = panel.data.character_id or ''

      return { operator = operator, character = character_id }
    end,
    icon = 'icon16/user.png',
    check = function(target, data)
      if !data.operator or !data.character_id then return false end

      return util.process_operator(data.operator, target:get_character_id(), data.character_id)
    end,
    set_parameters = function(id, data, panel, menu, parent)
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
