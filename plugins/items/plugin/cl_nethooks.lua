--- Client-side network receivers of the Items plugin: opens the menu of an item entity
-- that the local player uses, receives the inventories and the requests to open or close
-- them from the server, and rebuilds the player model preview when the server asks for it.

local IsValid = IsValid

Cable.receive('fl_player_use_item_entity', function(entity)
  if IsValid(entity) and entity.item then
    --- Called on the client to open the menu of an item.
    -- Here it is run when the server reports that the local player has pressed the use key
    -- on an item entity. An inventory slot runs it without the second argument when it is
    -- clicked. The Items plugin handles the hook by building the menu.
    -- @param instance_id [Number Instance id of the item]
    -- @param is_entity [Boolean true if the item lies in the world, nil if it is in an
    --   inventory; decides between the take and the drop option]
    hook.Run('PlayerUseItemMenu', entity.item.instance_id, true)
  end
end)

Cable.receive('fl_inventory_sync', function(data)
  local inventory = Inventories.stored[data.id] or Inventory.new(data.id)
  inventory.id = data.id
  inventory.title = data.title
  inventory.icon = data.icon
  inventory.type = data.inv_type
  inventory.width = data.width
  inventory.height = data.height
  inventory.slots = data.slots
  inventory.multislot = data.multislot
  inventory.disabled = data.disabled
  inventory.owner = data.owner
  inventory.instance_id = data.instance_id

  if data.owner and data.owner == PLAYER then
    PLAYER.inventories = PLAYER.inventories or {}
    PLAYER.inventories[inventory.type] = inventory
  end

  if IsValid(inventory.panel) then
    inventory.panel:rebuild()
  end

  --- Called on the client when an inventory has been received from the server.
  -- The local copy of the inventory has been updated by now and its panel, if it has
  -- one, has been rebuilt.
  -- @param inventory [Inventory The inventory that has been updated]
  hook.Run('OnInventorySync', inventory)
end)

Cable.receive('fl_inventories_clear', function()
  if !IsValid(PLAYER) then return end

  for id, inventory in pairs(Inventories.stored) do
    if inventory.owner == PLAYER then
      Inventories.stored[id] = nil
    end
  end

  PLAYER.inventories = nil
end)

Cable.receive('fl_rebuild_player_panel', function()
  if IsValid(Flux.tab_menu) and Flux.tab_menu:IsVisible() then
    local active_panel = Flux.tab_menu.active_panel

    if IsValid(active_panel) and active_panel.id == 'inventory' then
      local player_model = active_panel.player_model

      if IsValid(player_model) then
        player_model:rebuild()
      end
    end
  end
end)

Cable.receive('fl_open_player_inventory', function(owner, inventory_ids)
  local inventory = vgui.Create('fl_inventory_container')
  inventory:open_player_inventories(owner, inventory_ids)

  Flux.container_panel = inventory
end)

Cable.receive('fl_inventory_open', function(inventory_id)
  if !IsValid(Flux.tab_menu) and !IsValid(Flux.container_panel) then
    local inventory = vgui.Create('fl_inventory_container')
    inventory:open_inventory(inventory_id)

    Flux.container_panel = inventory
  else
    local inventory = Inventories.find(inventory_id)

    if !inventory then return end

    local item_obj = Item.find_instance_by_id(inventory.instance_id)
    local parent =
      IsValid(Flux.tab_menu) and Flux.tab_menu or IsValid(Flux.container_panel) and Flux.container_panel or nil
    local frame = vgui.Create('fl_frame', parent)

    local inventory_panel = inventory:create_panel(frame)
    inventory_panel:set_title()
    inventory_panel:SizeToContents()
    inventory_panel:rebuild()
    inventory_panel:Dock(FILL)

    local left, top, right, bottom = frame:GetDockPadding()

    frame:set_title(t(item_obj and item_obj:get_name() or inventory.title or inventory.type))
    frame:set_draggable(true)
    frame:SetSize(inventory_panel:GetWide() + left + right, inventory_panel:GetTall() + top + bottom)
    frame:SetPos(input.GetCursorPos())
    frame:MoveToFront()
    frame.inventory = inventory

    frame.OnRemove = function()
      local closed_inventory_id = frame.inventory.id
      Cable.send('fl_inventory_close', { closed_inventory_id })

      PLAYER.opened_containers[closed_inventory_id] = nil
    end

    PLAYER.opened_containers = PLAYER.opened_containers or {}
    PLAYER.opened_containers[inventory_id] = frame
  end
end)

Cable.receive('fl_inventory_close', function(inventory_id)
  local container_panel = Flux.container_panel

  if inventory_id then
    local inventory_panel = PLAYER.opened_containers and PLAYER.opened_containers[inventory_id]

    if IsValid(inventory_panel) then
      inventory_panel:safe_remove()
    elseif IsValid(container_panel) and table.HasValue(container_panel:get_inventory_ids() or {}, inventory_id) then
      container_panel:safe_remove()
    end
  else
    if IsValid(container_panel) then
      container_panel:safe_remove()
    end
  end
end)
