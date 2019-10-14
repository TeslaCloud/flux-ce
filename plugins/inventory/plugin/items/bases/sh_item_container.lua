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

-- Default inventory usage example:
-- ItemContainer.default_inventory = {
--   { id = 'test_item', amount = 5, data = {} }, -- Adds 5 test items to this container when creating it.
--   { id = 'test_item', amount = 1, data = { name = 'Test Item #2' } }  -- Adds another 1 test item with the name 'Test Item #2'.
-- }

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

function ItemContainer:get_inventory_data()
  return self.inventory_data
end

function ItemContainer:on_open(player)
  if !self.inventory then
    self:create_inventory()

    if self.items then
      self.inventory:load_items(self.items)

      self.items = nil
    end
  end

  player:open_inventory(self.inventory)
end

function ItemContainer:can_contain(item_obj)
  if item_obj == self then
    return false
  end
end

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

function ItemContainer:on_created()
  if !table.is_empty(self.default_inventory) then
    self:create_inventory()

    for k, v in pairs(self.default_inventory) do
      local success, error_text = self.inventory:give_item(v.id, v.amount, v.data)

      if !success then
        Flux.dev_print('Failed to give default item to ItemContainer: '..error_text)

        return
      end
    end
  end
end

function ItemContainer:on_save()
  if self.inventory then
    self.items = self.inventory:get_items_ids()
  end
end
