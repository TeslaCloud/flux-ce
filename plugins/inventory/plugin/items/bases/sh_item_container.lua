class 'ItemContainer' extends 'ItemBase'

ItemContainer.name = 'Container Items Base'
ItemContainer.description = 'An item that can be opened.'
ItemContainer.stackable = false
ItemContainer.inventory_data = {
  width = 4,
  height = 4,
  type = 'item_container',
  multislot = true
}

ItemContainer.default_inventory = {}

ItemContainer:add_button('item.option.open', {
  icon = 'icon16/briefcase.png',
  callback = 'on_open',
  on_show = function(item_obj)
    local containers = PLAYER.opened_containers

    if containers then
      for k, v in pairs(containers) do
        if IsValid(v) and v.inventory.instance_id == item_obj.instance_id then
          return false
        end
      end
    end
  end
})

--- Returns the settings that the inventory of the container is created with.
-- @return [Map table with width, height, type and multislot fields,
--   and optionally infinite_width and infinite_height]
function ItemContainer:get_inventory_data()
  return self.inventory_data
end

--- Called on the server when a player presses the open button in the item's menu.
-- Creates the inventory of the container if it does not exist yet,
-- fills it with the items that were saved, and opens it for the player.
-- @param actor [Player]
function ItemContainer:on_open(actor)
  if !self.inventory then
    self:create_inventory()

    if self.items then
      self.inventory:load_items(self.items)

      self.items = nil
    end
  end

  actor:open_inventory(self.inventory)
end

--- Called on the server by the 'CanItemTransfer' hook before an item is put
-- into the container. Prevents the container from being put inside of itself.
-- @param item_obj [Item the item that is being put into the container]
-- @return [Boolean false to prevent the transfer, nil otherwise]
function ItemContainer:can_contain(item_obj)
  if item_obj == self then
    return false
  end
end

--- Creates the inventory that stores the contents of the container
-- and puts it into the 'inventory' field of the item.
function ItemContainer:create_inventory()
  local inventory_data = self:get_inventory_data()

  local inventory = Inventory.new()
    inventory.title = self:get_name()
    inventory:set_size(inventory_data.width or 1, inventory_data.height or 1)
    inventory.type = inventory_data.type or 'item_container'
    inventory.multislot = inventory_data.multislot != nil and inventory_data.multislot or true
    inventory.infinite_width = inventory_data.infinite_width != nil and inventory_data.infinite_width or false
    inventory.infinite_height = inventory_data.infinite_height != nil and inventory_data.infinite_height or false
    inventory.instance_id = self.instance_id
  self.inventory = inventory
end

--- Called on the server by the 'OnItemCreated' hook right after an instance of the item
-- is created. Fills the container with the items listed in default_inventory.
function ItemContainer:on_created()
  if !table.IsEmpty(self.default_inventory) then
    self:create_inventory()

    for k, v in pairs(self.default_inventory) do
      local success, error_text = self.inventory:give_item(v.id, v.amount, v.data)

      if !success then
        Flux.dev_print('Failed to give a default item to ItemContainer: '..error_text)

        return
      end
    end
  end
end

--- Called on the server before the character of the player that has the item is saved.
-- Stores the instance ids of the contained items in the 'items' field of the item.
function ItemContainer:on_save()
  if self.inventory then
    self.items = self.inventory:get_items_ids()
  end
end
