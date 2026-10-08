--- Items are the objects that players carry, use, equip and drop.
-- An item starts as an item class, also called a template: a file in the `items/` folder
-- of a plugin or of the schema that is loaded through the `item` pipeline. The pipeline
-- creates an `ItemBase` object, exposes it as the `ITEM` global while the file runs and
-- registers it under the id taken from the file name (`sh_test_item.lua` becomes
-- `test_item`). An item class can build upon a base class from an `items/bases/` folder
-- with `ItemBase:base_off`; this plugin comes with `ItemUsable`, `ItemConsumable`,
-- `ItemAmmo`, `ItemEquipable`, `ItemWeapon`, `ItemThrowable` and `ItemWearable`.
--
-- What players actually own are item instances: copies of a template made by
-- `Item.create`, each with its own numeric instance id and custom data. The server saves
-- the instances and sends them to the clients. An instance either sits in an inventory
-- (see the Inventory plugin) or lies in the world as an `fl_item` entity spawned by
-- `Item.spawn`. Players act on an instance through its menu: the use, take and drop options
-- and the custom buttons of the item all end up in `ItemBase:do_menu_action` on the
-- server, which runs the `PlayerCanUseItem`, `PlayerUseItem`, `PlayerTakeItem`,
-- `PlayerDropItem` and `PlayerUsedItem` hooks.
--
-- Once this plugin is loaded, every plugin and the schema get their `items/bases/` and
-- `items/` folders included, so adding an item only takes a file:
-- ```
-- ITEM:base_off 'ItemUsable'
-- ITEM.name = 'Bandage'
-- ITEM.description = 'A roll of clean cloth.'
-- ITEM.model = 'models/props_lab/box01a.mdl'
--
-- function ITEM:use(actor)
--   actor:SetHealth(math.min(actor:Health() + 10, actor:GetMaxHealth()))
-- end
-- ```
-- The plugin also registers the `has_item` and `has_item_data` conditions.
-- @module [Items]

PLUGIN:set_global('Items')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
require_relative 'sh_enums'

--- Registers the 'items/bases' and 'items' plugin folders
-- and includes the item bases and the items that come with this plugin.
function Items:OnPluginLoaded()
  Plugin.add_extra('items/bases')
  Plugin.add_extra('items')

  require_relative_folder(self:get_folder()..'/items/bases')
  Item.include_items(self:get_folder()..'/items/')
end

--- Includes the items of a plugin when its 'items' folder is being included.
-- @param extra [String name of the folder being included]
-- @param folder [String path to the plugin's folder]
-- @return [Boolean true if the folder was handled here, nil otherwise]
function Items:PluginIncludeFolder(extra, folder)
  if extra == 'items' then
    Item.include_items(folder..'/items/')

    return true
  end
end

--- Registers the 'has_item' and 'has_item_data' conditions.
function Items:RegisterConditions()
  Conditions:register_condition('has_item', {
    name = 'condition.has_item.name',
    text = 'condition.has_item.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local parameter = panel.data.item_id or ''

      return { operator = operator, item = parameter }
    end,
    icon = 'icon16/brick.png',
    check = function(target, data)
      if !data.operator or !data.item_id then return false end

      return util.process_operator(data.operator, target:has_item(data.item_id), true)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      Derma_StringRequest(
        t(data.name),
        t'condition.has_item.message',
        '',
        function(text)
          panel.data.item_id = text:lower()

          panel.update()
        end)
    end,
    set_operator = 'equal'
  })

  Conditions:register_condition('has_item_data', {
    name = 'condition.has_item_data.name',
    text = 'condition.has_item_data.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local item_id = panel.data.item_id or ''
      local key = panel.data.key or ''
      local value = panel.data.value or ''

      return { operator = operator, item = item_id, key = key, value = value }
    end,
    icon = 'icon16/brick_add.png',
    check = function(target, data)
      if !data.operator or !data.item_id or !data.key or !data.value then return false end

      local items = target:find_items(data.item_id)

      if #items == 0 then
        return false
      end

      for k, v in pairs(items) do
        local value = v:get_data(data.key)

        if value then
          return util.process_operator(data.operator, value, data.value)
        end
      end

      return false
    end,
    set_parameters = function(id, data, panel, menu, parent)
      Derma_StringRequest(
        t(data.name),
        t'condition.has_item_data.message1',
        '',
        function(text)
          panel.data.item_id = text:lower()

          panel.update()

          Derma_StringRequest(
            t(data.name),
            t'condition.has_item_data.message2',
            '',
            function(text)
              panel.data.key = text

              panel.update()

              Derma_StringRequest(
                t(data.name),
                t'condition.has_item_data.message3',
                '',
                function(text)
                  panel.data.value = text

                  panel.update()
                end)
            end)
        end)
    end,
    set_operator = 'equal'
  })
end
