class 'ItemContainer' extends 'ItemBase'

ItemContainer.name = 'Usable Items Base'
ItemContainer.description = 'An item that can be used.'
ItemContainer.stackable = false
ItemContainer.inventory_data = {
  width = 4,
  height = 4,
  type = 'item_container',
  multislot = true
}

ItemContainer:add_button('item.option.open', {
  icon = 'icon16/briefcase.png',
  callback = 'on_open',
  on_show = function(item_table)
    local containers = PLAYER.opened_containers

    if containers then
      for k, v in pairs(containers) do
        if IsValid(v) and v.inventory.instance_id == item_table.instance_id then
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
    local inventory_data = self:get_inventory_data()

    local inventory = Inventory.new()
      inventory.title = self:get_name()
      inventory:set_size(inventory_data.width, inventory_data.height)
      inventory.type = inventory_data.type
      inventory.multislot = inventory_data.multislot
      inventory.instance_id = self.instance_id
    self.inventory = inventory

    if self.items then
      inventory:load_items(self.items)

      self.items = nil
    end
  end

  player:open_inventory(self.inventory)
end

function ItemContainer:can_contain(item_table)
  if item_table == self then
    return false
  end
end

function ItemContainer:on_instanced()

end

function ItemContainer:on_save()
  if self.inventory then
    self.items = self.inventory:get_items_ids()
  end
end
