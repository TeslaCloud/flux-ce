function Inventories:OnContextMenuOpen()
  if IsValid(PLAYER.hotbar) then
    PLAYER.hotbar:safe_remove()
  end

  timer.destroy('fl_hotbar_popup')

  PLAYER.hotbar = Inventories:create_hotbar()
  PLAYER.hotbar:SetAlpha(255)
  PLAYER.hotbar:MakePopup()
  PLAYER.hotbar:MoveToFront()
  PLAYER.hotbar:SetMouseInputEnabled(true)
  PLAYER.hotbar:rebuild()
end

function Inventories:OnContextMenuClose()
  if IsValid(PLAYER.hotbar) then
    PLAYER.hotbar:safe_remove()
  end
end

function Inventories:AddTabMenuItems(menu)
  menu:add_menu_item('inventory', {
    title = 'Inventory',
    panel = 'fl_inventory_menu',
    icon = 'fa-briefcase',
    default = true,
    priority = 30,
    callback = function(menu_panel, button)
      local inv = menu_panel.active_panel
      inv:SetTitle('Inventory')
    end
  })
end

function Inventories:OnInventoryRebuild(panel)
  if panel:get_inventory_type() == 'pockets' then
    local parent = panel:GetParent()
    panel:SizeToContents()
    panel:SetWide(math.min(panel:GetWide(), parent.main_inventory:GetWide()))
  end
end

function Inventories:create_hotbar()
  local hotbar = PLAYER:get_inventory('hotbar'):create_panel()
  hotbar:set_slot_size(math.scale(80))
  hotbar:set_slot_padding(math.scale(8))
  hotbar:draw_inventory_slots(true)
  hotbar:set_title()
  hotbar:SizeToContents()
  hotbar:SetPos(ScrW() * 0.5 - hotbar:GetWide() * 0.5, ScrH() - hotbar:GetTall() - math.scale(16))

  return hotbar
end

function Inventories:popup_hotbar()
  if !IsValid(PLAYER.hotbar) then
    PLAYER.hotbar = Inventories:create_hotbar()
    PLAYER.hotbar:rebuild()

    timer.create('fl_hotbar_popup', 0.05, 0, function()
      if IsValid(PLAYER.hotbar) then
        local alpha = PLAYER.hotbar:GetAlpha()
        PLAYER.hotbar:SetAlpha(alpha - 5)

        if alpha <= 50 then
          PLAYER.hotbar:safe_remove()
        end
      else
        timer.destroy('fl_hotbar_popup')
      end
    end)
  else
    PLAYER.hotbar:SetAlpha(255)
  end
end

function Inventories:OnMenuPanelOpen(menu_panel, active_panel)
  if PLAYER.opened_containers then
    for k, v in pairs(PLAYER.opened_containers) do
      if IsValid(v) then
        v:safe_remove()
      end
    end

    PLAYER.opened_containers = {}
  end
end

function Inventories:CanItemMenuOpen(item_obj)
  local inventory = Inventories.find(item_obj.inventory_id)

  if inventory and inventory.instance_id then
    return false
  end
end

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

  hook.run('OnInventorySync', inventory)
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

Cable.receive('fl_open_player_inventory', function(player, inventory_ids)
  local inventory = vgui.create('fl_inventory_container')
  inventory:open_player_inventories(player, inventory_ids)

  Flux.container_panel = inventory
end)

Cable.receive('fl_inventory_open', function(inventory_id)
  if !IsValid(Flux.tab_menu) and !IsValid(Flux.container_panel) then
    local inventory = vgui.create('fl_inventory_container')
    inventory:open_inventory(inventory_id)

    Flux.container_panel = inventory
  else
    local inventory = Inventories.find(inventory_id)
    local item_obj = Item.find_instance_by_id(inventory.instance_id)
    local parent = IsValid(Flux.tab_menu) and Flux.tab_menu or IsValid(Flux.container_panel) and Flux.container_panel or nil
    local frame = vgui.create('fl_frame', parent)

    local inventory_panel = inventory:create_panel(frame)
    inventory_panel:set_title()
    inventory_panel:SizeToContents()
    inventory_panel:rebuild()
    inventory_panel:Dock(FILL)

    local left, top, right, bottom = frame:GetDockPadding()

    frame:set_title(t(item_obj:get_name()))
    frame:set_draggable(true)
    frame:SetSize(inventory_panel:GetWide() + left + right, inventory_panel:GetTall() + top + bottom)
    frame:SetPos(input.GetCursorPos())
    frame:MoveToFront()
    frame.inventory = inventory

    frame.OnRemove = function()
      local inventory_id = frame.inventory.id
      Cable.send('fl_inventory_close', { inventory_id })

      PLAYER.opened_containers[inventory_id] = nil
    end

    PLAYER.opened_containers = PLAYER.opened_containers or {}
    PLAYER.opened_containers[inventory_id] = frame
  end
end)

Cable.receive('fl_inventory_close', function(inventory_id)
  if inventory_id then
    local inventory_panel = PLAYER.opened_containers[inventory_id]

    if IsValid(inventory_panel) then
      inventory_panel:safe_remove()
    end
  else
    if IsValid(Flux.container_panel) then
      Flux.container_panel:safe_remove()
    end
  end
end)

local function create_item_icon(item_obj, parent)
  local icon = spawnmenu.CreateContentIcon('model', parent, {
    model = item_obj:get_model(),
    skin = item_obj:get_skin(),
    wide = math.scale(128),
    tall = math.scale(128)
  })

  local padding = math.scale(4)
  icon:DockPadding(padding, padding, padding, padding)

  local name_label = vgui.create('DLabel', icon)
  name_label:SetText(t(item_obj:get_real_name()))
  name_label:Dock(BOTTOM)
  name_label:SetTextColor(color_white)
  name_label:SetFont(Theme.get_font('text_bar'))
  name_label:SetWrap(true)
  name_label:SetAutoStretchVertical(true)

  padding = math.scale(2)

  name_label.Paint = function(pnl, w, h)
    DisableClipping(true)
      draw.RoundedBox(math.scale(4), -padding, -padding, w + padding * 2, h + padding * 2, Color(0, 0, 0, 150))
    DisableClipping(false)
  end

  icon:SetToolTip(t(item_obj:get_real_name())..'\n'..t(item_obj:get_description()))
  icon.DoRightClick = function(pnl)
    local derma_menu = DermaMenu()
    local give_self = derma_menu:AddSubMenu(t'ui.spawnmenu.give.self')

    if item_obj.stackable then
      give_self:AddOption(t'ui.spawnmenu.give.stack', function()
        MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, item_obj.max_stack)
      end)
    end

    give_self:AddOption(t'ui.spawnmenu.give.one', function()
      MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, 1)
    end)

    local players = player.all()

    if #players > 1 then
      local give_player = derma_menu:AddSubMenu(t'ui.spawnmenu.give.player')

      for k, v in ipairs(players) do
        if PLAYER == v then continue end

        local player_line = give_player:AddSubMenu(v:Name())

        if item_obj.stackable then
          player_line:AddOption(t'ui.spawnmenu.give.stack', function()
            MVC.push('SpawnMenu::GiveItem', v, item_obj.id, item_obj.max_stack)
          end)
        end

        player_line:AddOption(t'ui.spawnmenu.give.one', function()
          MVC.push('SpawnMenu::GiveItem', v, item_obj.id, 1)
        end)
      end
    end

    derma_menu:Open()
  end

  return icon
end

function Inventories:spawnmenu_populate_items(content_panel, tree, node)
  local categories = {}

  for id, item_obj in pairs(Item.all()) do
    if !categories[item_obj.category] then
      categories[item_obj.category] = {}
    end

    table.insert(categories[item_obj.category], item_obj)
  end

  for name, category in pairs(categories) do
    local node = tree:AddNode(t(name), Item.get_category_icon(name))

    node.DoPopulate = function(pnl)
      if IsValid(pnl.list) then return end

      pnl.list = vgui.create('ContentContainer', content_panel)
      pnl.list:SetVisible(false)
      pnl.list:SetTriggerSpawnlistChange(false)

      for k, item_obj in SortedPairsByMemberValue(category, 'name') do
        local icon = create_item_icon(item_obj, pnl.list)
        icon.DoClick = function(pnl)
          MVC.push('SpawnMenu::SpawnItem', item_obj.id)
        end
      end
    end

    node.DoClick = function(pnl)
      pnl:DoPopulate()
      content_panel:SwitchPanel(pnl.list)
    end
  end
end

function Inventories:PopulateSpawnMenu()
  spawnmenu.AddCreationTab(t'ui.spawnmenu.items', function()
    local panel = vgui.Create('SpawnmenuContentPanel')
    panel:EnableSearch('items', 'spawnmenu_populate_items')
    panel:CallPopulateHook('spawnmenu_populate_items')

    return panel
  end, 'icon16/briefcase.png', 40)
end

search.AddProvider(function(query)
  query = query:utf8lower()

  local results = {}

  for k, item_obj in pairs(Item.all()) do
    if t(item_obj:get_name()):utf8lower():find(query) then
      table.insert(results, {
        text = item_obj.id,
        func = function() MVC.push('SpawnMenu::SpawnItem', item_obj.id) end,
        icon = create_item_icon(item_obj),
        words = { item_obj }
      })
    end
  end

  return results
end, 'items')

concommand.Add('fl_icon_editor', function()
  if IsValid(Flux.icon_editor) then
    Flux.icon_editor:safe_remove()
  end

  Flux.icon_editor = vgui.create('fl_icon_editor')
end)
