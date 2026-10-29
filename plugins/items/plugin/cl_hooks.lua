--- Client hooks of the Items plugin: shows the progress of picking an item up by holding
-- the use key, builds the menu of an item with its use, take, drop, destroy and custom
-- options, shows the hotbar while the context menu is open, adds the inventory tab to the
-- tab menu, and adds the items tab to the spawn menu along with the `fl_icon_editor`
-- console command.

local IsValid = IsValid
local ScrW = ScrW
local ScrH = ScrH
local math_scale = math.scale

local label_background_color = Color(10, 12, 17, 200)

local aborted_hold_start
local held_entities = {}

--- Fills the circular progress indicator while the local player holds the use key on an item.
function Items:HUDPaint()
  local client = PLAYER

  if !IsValid(client) then return end

  local hold_start = client:get_nv('hold_start')

  if hold_start then
    local diff = math.Clamp(math.Round(CurTime() - hold_start, 3), 0.01, 0.5)
    local percentage = math.Clamp(diff * 200, 0, 100)

    Flux.set_circle_percent(percentage)
  end
end

--- Draws a halo around the item entity that the local player holds the use key on.
function Items:PreDrawHalos()
  local client = PLAYER

  if !IsValid(client) then return end

  local ent = client:get_nv('hold_entity')

  if IsValid(ent) then
    held_entities[1] = ent

    halo.Add(held_entities, color_white)
  end
end

--- Aborts taking an item once it gets too far from the center of the local player's screen.
-- The server is asked once per hold.
function Items:Think()
  local client = PLAYER

  if !IsValid(client) then return end

  local hold_start = client:get_nv('hold_start')

  if !hold_start or hold_start == aborted_hold_start then return end

  local ent = client:get_nv('hold_entity')

  if IsValid(ent) then
    local scr_pos = ent:GetPos():ToScreen()
    local x, y = scr_pos.x, scr_pos.y
    local w, h = ScrW() * 0.5, ScrH() * 0.5
    local max_offset = math_scale(350)

    if !scr_pos.visible or math.abs(w - x) > max_offset or math.abs(h - y) > max_offset then
      aborted_hold_start = hold_start

      Cable.send('fl_items_abort_hold_start', true)
    end
  end
end

--- Asks the local player whether they really want to destroy an item, and requests the
-- 'on_destroy' menu action from the server if they do.
-- @param item_obj [Item the item instance to destroy]
function Items:confirm_destroy(item_obj)
  local message = t('ui.item.destroy_message', { item = t(item_obj:get_name()) })
  local decline_text = t'ui.no'

  Derma_Query(message, t'ui.item.destroy_title', t'ui.yes', function()
    item_obj:do_menu_action('on_destroy')
  end, decline_text)
end

--- Opens the menu of an item with its custom buttons and the use, take and drop options,
-- and the destroy option if the item is destroyable and in an inventory.
-- @param instance_id [Number instance id of the item]
-- @param is_entity=nil [Boolean true if the item is lying in the world, not in an inventory]
function Items:PlayerUseItemMenu(instance_id, is_entity)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj then return end

  --- Called on the client before the menu of an item is opened.
  -- @param item_obj [Item The item instance the menu is for]
  -- @return [Boolean Return false to prevent the menu from opening]
  if hook.Run('CanItemMenuOpen', item_obj) == false then return end

  local item_menu = vgui.Create('fl_menu')

  if item_obj.name then
    if item_obj.custom_buttons then
      for id, custom_button in pairs(item_obj.custom_buttons) do
        if !custom_button.on_show or custom_button.on_show(item_obj) != false then
          local button = item_menu:add_option(t(custom_button.get_name and custom_button.get_name(item_obj)
            or custom_button.name or id), function()
            if custom_button.on_click then
              custom_button.on_click(item_obj)
            end

            item_obj:do_menu_action(custom_button.callback)
          end)

          button:SetIcon(custom_button.get_icon and custom_button.get_icon(item_obj) or custom_button.icon)
        end
      end
    end

    if item_obj.on_use then
      if !item_obj.is_action_visible or item_obj:is_action_visible('use') != false then
        local use_button = item_menu:add_option(t(item_obj:get_use_text()), function()
          item_obj:do_menu_action('on_use')
        end)

        use_button:SetIcon(item_obj.use_icon or 'icon16/accept.png')
      end
    end

    if is_entity then
      if !item_obj.is_action_visible or item_obj:is_action_visible('take') != false then
        local take_button = item_menu:add_option(t(item_obj:get_take_text()), function()
          item_obj:do_menu_action('on_take')
        end)

        take_button:SetIcon(item_obj.take_icon or 'icon16/add.png')
      end
    else
      if !item_obj.is_action_visible or item_obj:is_action_visible('drop') != false then
        local drop_button = item_menu:add_option(t(item_obj:get_drop_text()), function()
          item_obj:do_menu_action('on_drop')
        end)

        drop_button:SetIcon(item_obj.drop_icon or 'icon16/arrow_down.png')
      end

      if item_obj:is_destroyable()
      and (!item_obj.is_action_visible or item_obj:is_action_visible('destroy') != false) then
        local destroy_button = item_menu:add_option(t(item_obj:get_destroy_text()), function()
          self:confirm_destroy(item_obj)
        end)

        destroy_button:SetIcon(item_obj.destroy_icon or 'icon16/cross.png')
      end
    end
  end

  item_menu:open()

  if is_entity then
    item_menu:SetPos(ScrW() * 0.5, ScrH() * 0.5)
  else
    local x, y = gui.MouseX(), gui.MouseY()

    if x + item_menu:GetWide() > ScrW() then
      x -= item_menu:GetWide()
    end

    if y + item_menu:GetTall() > ScrH() then
      y -= item_menu:GetTall()
    end

    item_menu:SetPos(x, y)
  end
end

--- Shows the hotbar and makes it interactive while the context menu is open, if the player
-- has one; a player without a character, such as a gamemaster in gamemaster mode, has none.
function Items:OnContextMenuOpen()
  if !PLAYER:get_inventories().hotbar then return end

  if IsValid(PLAYER.hotbar) then
    PLAYER.hotbar:safe_remove()
  end

  timer.Destroy('fl_hotbar_popup')

  local hotbar = self:create_hotbar()

  PLAYER.hotbar = hotbar
  hotbar:SetAlpha(255)
  hotbar:MakePopup()
  hotbar:MoveToFront()
  hotbar:SetMouseInputEnabled(true)
  hotbar:rebuild()
end

--- Removes the hotbar when the context menu closes.
function Items:OnContextMenuClose()
  if IsValid(PLAYER.hotbar) then
    PLAYER.hotbar:safe_remove()
  end
end

--- Adds the inventory to the tab menu, if the player has inventories. A player without a
-- character, such as a gamemaster in gamemaster mode, has none; the inventory is then also
-- forgotten as the page to reopen, since the tab menu expects the page it reopens to exist.
-- @param menu [Panel the tab menu]
function Items:AddTabMenuItems(menu)
  if !PLAYER.inventories then
    if PLAYER.tab_panel == 'inventory' then
      PLAYER.tab_panel = nil
    end

    return
  end

  menu:add_menu_item('inventory', {
    title = t'ui.tab_menu.inventory',
    panel = 'fl_inventory_menu',
    icon = 'fa-briefcase',
    default = true,
    priority = 30,
    callback = function(menu_panel, _button)
      local inv = menu_panel.active_panel
      inv:SetTitle('Inventory')
    end
  })
end

--- Keeps the pockets panel no wider than the main inventory panel of the local player shown
-- in the same view, if there is one.
-- @param panel [Panel the fl_inventory panel that has been rebuilt]
function Items:OnInventoryRebuild(panel)
  if panel:get_inventory_type() == 'pockets' then
    local parent = panel:GetParent()
    panel:SizeToContents()

    if !IsValid(parent.main_inventory) then return end

    panel:SetWide(math.min(panel:GetWide(), parent.main_inventory:GetWide()))
  end
end

--- Closes the windows of all opened container items when a tab menu panel opens.
-- @param _menu_panel [Panel the tab menu]
-- @param _active_panel [Panel the panel that has been opened]
function Items:OnMenuPanelOpen(_menu_panel, _active_panel)
  if PLAYER.opened_containers then
    for _, container in pairs(PLAYER.opened_containers) do
      if IsValid(container) then
        container:safe_remove()
      end
    end

    PLAYER.opened_containers = {}
  end
end

--- Prevents opening the menu of items that are stored inside of container items.
-- @param item_obj [Item]
-- @return [Boolean false to prevent the menu from opening, nil otherwise]
function Items:CanItemMenuOpen(item_obj)
  local inventory = Inventories.find(item_obj.inventory_id)

  if inventory and inventory.instance_id then
    return false
  end
end

local function create_item_icon(item_obj, parent)
  local icon = spawnmenu.CreateContentIcon('model', parent, {
    model = item_obj:get_model(),
    skin = item_obj:get_skin(),
    wide = math_scale(128),
    tall = math_scale(128)
  })

  local padding = math_scale(4)
  icon:DockPadding(padding, padding, padding, padding)

  local name_label = vgui.Create('DLabel', icon)
  name_label:SetText(t(item_obj:get_real_name()))
  name_label:Dock(BOTTOM)
  name_label:SetTextColor(color_white)
  name_label:SetFont(Theme.get_font('text_bar'))
  name_label:SetWrap(true)
  name_label:SetAutoStretchVertical(true)

  padding = math_scale(2)

  local padding_double = padding * 2
  local corner_radius = math_scale(4)

  name_label.Paint = function(_pnl, w, h)
    DisableClipping(true)
      draw.RoundedBox(corner_radius, -padding, -padding, w + padding_double, h + padding_double, label_background_color)
    DisableClipping(false)
  end

  icon:SetToolTip(t(item_obj:get_real_name())..'\n'..t(item_obj:get_description()))
  icon.DoRightClick = function(_pnl)
    local derma_menu = DermaMenu()
    local give_self = derma_menu:AddSubMenu(t'ui.spawnmenu.give.self', false)

    if item_obj.stackable then
      give_self:AddOption(t'ui.spawnmenu.give.stack', function()
        MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, item_obj.max_stack)
      end)
    end

    give_self:AddOption(t'ui.spawnmenu.give.one', function()
      MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, 1)
    end)

    if player.GetCount() > 1 then
      local give_player = derma_menu:AddSubMenu(t'ui.spawnmenu.give.player', false)

      for _, client in player.Iterator() do
        if PLAYER == client then continue end

        local player_line = give_player:AddSubMenu(client:Name())

        if item_obj.stackable then
          player_line:AddOption(t'ui.spawnmenu.give.stack', function()
            MVC.push('SpawnMenu::GiveItem', client, item_obj.id, item_obj.max_stack)
          end)
        end

        player_line:AddOption(t'ui.spawnmenu.give.one', function()
          MVC.push('SpawnMenu::GiveItem', client, item_obj.id, 1)
        end)
      end
    end

    derma_menu:Open()
  end

  return icon
end

--- Fills the items tab of the spawn menu with a node for every item category.
-- @param content_panel [Panel the content panel of the tab]
-- @param tree [Panel the navigation tree of the tab]
-- @param _node [Panel]
function Items:spawnmenu_populate_items(content_panel, tree, _node)
  local categories = {}

  for _id, item_obj in pairs(Item.all()) do
    local category = categories[item_obj.category]

    if !category then
      category = {}
      categories[item_obj.category] = category
    end

    category[#category + 1] = item_obj
  end

  for name, category in pairs(categories) do
    local node = tree:AddNode(t(name), Item.get_category_icon(name))

    node.DoPopulate = function(pnl)
      if IsValid(pnl.list) then return end

      pnl.list = vgui.Create('ContentContainer', content_panel)
      pnl.list:SetVisible(false)
      pnl.list:SetTriggerSpawnlistChange(false)

      for _, item_obj in SortedPairsByMemberValue(category, 'name') do
        local icon = create_item_icon(item_obj, pnl.list)
        icon.DoClick = function(_pnl)
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

--- Adds the items tab to the spawn menu.
function Items:PopulateSpawnMenu()
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

  for _, item_obj in pairs(Item.all()) do
    if t(item_obj:get_name()):utf8lower():find(query, 1, true) then
      results[#results + 1] = {
        text = item_obj.id,
        func = function() MVC.push('SpawnMenu::SpawnItem', item_obj.id) end,
        icon = create_item_icon(item_obj),
        words = { item_obj }
      }
    end
  end

  return results
end, 'items')

concommand.Add('fl_icon_editor', function()
  if IsValid(Flux.icon_editor) then
    Flux.icon_editor:safe_remove()
  end

  Flux.icon_editor = vgui.Create('fl_icon_editor')
end)
