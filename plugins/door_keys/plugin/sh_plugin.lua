--- Door Keys adds keys that belong to doors. Staff with the 'manage_doors' permission create
-- a key for a door, add existing keys to it, list its keys and take them off it from the keys
-- property of the door menu. A player with a key molding kit uses up a key blank to copy one of
-- their keys. Holding a key lets a player lock and unlock every door it belongs to.
-- `AdjustKeyCopy` lets plugins change the copy of a key before the player receives it.

PLUGIN:set_global('DoorKeys')

require_relative 'cl_plugin'
require_relative 'sv_hooks'

Item.set_category_icon('item.category.keys', 'icon16/key.png')

--- Registers the keys door property, which adds a menu to list, create and add keys.
function DoorKeys:RegisterDoorProperties()
  Doors:register_property('keys', {
    create_panel = function(entity, panel)
      local keys_list = panel.properties:CreateRow(t'door.categories.general', t'door.properties.keys_list.name')
      keys_list:Setup('Combo', { text = t'door.properties.keys_list.select' })

      keys_list:AddChoice(t'door.properties.keys_list.show', function()
        Cable.send('fl_key_show_list', entity)
      end)

      keys_list:AddChoice(t'door.properties.keys_list.create', function()
        Cable.send('fl_key_create', entity)
      end)

      keys_list:AddChoice(t'door.properties.keys_list.add', function()
        DoorKeys:select_key(entity)
      end)

      keys_list.DataChanged = function(_pnl, callback)
        if callback then
          callback()
        end
      end
    end
  })
end
