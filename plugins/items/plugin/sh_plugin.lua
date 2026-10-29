--- Items are the objects that players carry, use, equip and drop.
-- An item starts as an item class, also called a template: a file in the `items/` folder
-- of a plugin or of the schema that is loaded through the `item` pipeline. The pipeline
-- creates an `ItemBase` object, exposes it as the `ITEM` global while the file runs and
-- registers it under the id taken from the file name (`sh_test_item.lua` becomes
-- `test_item`). An item class can build upon a base class from an `items/bases/` folder
-- with `ItemBase:base_off`; this plugin comes with `ItemUsable`, `ItemConsumable`,
-- `ItemMedical`, `ItemAmmo`, `ItemEquipable`, `ItemWeapon`, `ItemThrowable`,
-- `ItemWearable` and `ItemContainer`.
--
-- What players actually own are item instances, made out of a template by `Item.create`,
-- each with its own numeric instance id and custom data. An instance either sits in an
-- inventory or lies in the world as an `fl_item` entity spawned by `Item.spawn`. Every
-- instance is a row of the `items` table of the database; the server loads the instances
-- when they are needed and writes back what changes (see `lib/sv_storage.lua`), and sends
-- each client the instances it needs. Players act on an instance through its menu: the
-- use, take, drop and destroy options and the custom buttons of the item all end up in
-- `ItemBase:do_menu_action` on the server, which runs the `PlayerCanUseItem`,
-- `PlayerUseItem`, `PlayerTakeItem`, `PlayerDropItem`, `PlayerDestroyItem` and
-- `PlayerUsedItem` hooks, which this plugin handles by doing what the action says.
--
-- Inventories are where players and other objects keep their items.
-- An `Inventory` is a grid of slots, `width` by `height`, with a numeric id and a type such
-- as `'main_inventory'` or `'hotbar'`. Every slot holds a stack of item instance ids. In
-- a multislot inventory an item covers as many slots as its `width` and `height` say and
-- can be rotated; in any other inventory every item takes a single slot. An inventory
-- can also grow with its contents (`infinite_width`, `infinite_height`) and be disabled.
-- `Inventories.find` looks an inventory up by its id.
--
-- When a character becomes active, the `CreatePlayerInventories` hook builds the
-- inventories of the player. This plugin creates the main inventory, the hotbar, the
-- pockets and the equipment slots there, sized by the `inventory_`, `hotbar_` and
-- `pockets_` config keys, and other plugins can add their own. The items of the character
-- are then loaded from the database into them, and they are written back and unloaded
-- once the character is no longer in use, so a character keeps its items from map to map.
-- Further inventories can be created with `Inventory.new` for anything else that holds
-- items, such as the bags based on `ItemContainer`, and shown to a player with
-- `Player:open_inventory`.
--
-- Inventories are managed by the server. Each one has a list of receivers: the players
-- who are sent its contents whenever `Inventory:sync` is called, and the only ones whose
-- requests to move or drop its items are accepted. A player is a receiver of their own
-- inventories and of those that were opened for them; once a second the server closes the
-- opened ones for the players who are no longer entitled to them, such as those who have
-- walked away from a container (`Inventory:can_be_viewed_by`). The client keeps a copy
-- and displays it in an `fl_inventory` panel made of `fl_inventory_item` slots. Dragging
-- an item to another slot asks the server to move it, which goes through the
-- `PlayerCanMoveItem`, `CanItemMove` or `CanItemTransfer`, `PreItemTransfer` and
-- `ItemTransferred` hooks; dragging it out of the panel drops it into the world. The
-- `fl_inventory_menu` panel is the inventory tab of the tab menu, and
-- `fl_inventory_container` shows another inventory next to the player's own.
--
-- Five config keys of the plugin, all off by default, let players destroy the items in
-- their inventories (`item_destroy`), give the items that lie in the world health so that
-- they can be destroyed by damage (`item_entity_health`), keep players away from the items
-- that another of their own characters has dropped (`item_drop_ownership`), make
-- ammunition require a weapon that uses it (`ammo_requires_weapon`) and drop the equipped
-- weapons of players who die (`drop_weapons_on_death`).
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
-- The plugin also lets the slot binds select the items of the hotbar, and adds the
-- GiveItem command, the 'item' argument type that completes item IDs for commands, an
-- items tab to the spawn menu, and the `has_item` and `has_item_data` conditions.
-- @module [Items]

PLUGIN:set_global('Items')

local function complete_item()
  local ids = {}

  for item_id in pairs(Item.all()) do
    ids[#ids + 1] = item_id
  end

  table.sort(ids)

  return ids
end

Flux.Command:add_completer('item', complete_item)

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sh_hooks'
require_relative 'sv_hooks'
require_relative 'cl_nethooks'
require_relative 'sv_nethooks'

--- Registers the 'spawn_items' and 'give_items' permissions of the items tab of the spawn menu.
function Items:RegisterPermissions()
  Bolt:register_permission(
    'spawn_items',
    'permission.spawn_items.name',
    'permission.spawn_items.description',
    'permission.categories.spawn'
  )
  Bolt:register_permission(
    'give_items',
    'permission.give_items.name',
    'permission.give_items.description',
    'permission.categories.character_management'
  )
end

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
    get_args = function(panel, _data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local parameter = panel.data.item_id or ''

      return { operator = operator, item = parameter }
    end,
    icon = 'icon16/brick.png',
    check = function(target, data)
      if !data.operator or !data.item_id then return false end

      return util.process_operator(data.operator, target:has_item(data.item_id), true)
    end,
    set_parameters = function(_id, data, panel, _menu, _parent)
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
    get_args = function(panel, _data)
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

      for _, item_obj in pairs(items) do
        local value = item_obj:get_data(data.key)

        if value then
          return util.process_operator(data.operator, value, data.value)
        end
      end

      return false
    end,
    set_parameters = function(_id, data, panel, _menu, _parent)
      Derma_StringRequest(
        t(data.name),
        t'condition.has_item_data.message1',
        '',
        function(item_id)
          panel.data.item_id = item_id:lower()

          panel.update()

          Derma_StringRequest(
            t(data.name),
            t'condition.has_item_data.message2',
            '',
            function(key)
              panel.data.key = key

              panel.update()

              Derma_StringRequest(
                t(data.name),
                t'condition.has_item_data.message3',
                '',
                function(value)
                  panel.data.value = value

                  panel.update()
                end)
            end)
        end)
    end,
    set_operator = 'equal'
  })
end
