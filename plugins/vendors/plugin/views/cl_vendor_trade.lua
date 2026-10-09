--- The trade panel of a vendor (`fl_vendor_trade`) and the panels it is made of.
-- The panel is a frame with two lists (`fl_vendor_list`) of rows (`fl_vendor_row`): what the
-- vendor sells, with prices and stock, and the items of the local player that the vendor
-- buys, with what it pays for them. The buttons of the rows ask the server to buy or to sell
-- one item; the server answers with fresh contents for the panel. Removing the panel tells
-- the server that the trade is over.
--
-- A theme can draw the rows and the lists itself with `PaintVendorRow(panel, w, h)` and
-- `PaintVendorList(panel, w, h)`: returning anything but nil replaces the default drawing.

local PANEL = {}
PANEL.name = ''
PANEL.info = ''
PANEL.price = ''

--- Creates the icon and the button of the row.
function PANEL:Init()
  local padding = math.scale(4)
  local height = math.scale(56)

  self:SetTall(height)
  self:Dock(TOP)
  self:DockMargin(0, 0, 0, padding)
  self:DockPadding(padding, padding, padding, padding)

  self.icon = vgui.Create('SpawnIcon', self)
  self.icon:SetWide(height - padding * 2)
  self.icon:Dock(LEFT)
  self.icon:SetMouseInputEnabled(false)

  self.button = vgui.Create('fl_button', self)
  self.button:SetWide(math.scale(104))
  self.button:Dock(RIGHT)
  self.button:SetFont(Theme.get_font('main_menu_small'))
  self.button:set_centered(true)
  self.button:set_draw_outline(true)
  self.button:set_background_color(Theme.get_color('accent'))
end

--- Draws the background of the row, the name of the item, the line below it and the price.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  --- Lets the active theme draw a row of the trade panel of a vendor itself. Called on the
  -- client every frame for every visible row.
  -- @param panel [Panel The `fl_vendor_row` panel; its `name`, `info` and `price` fields hold
  --   the texts of the row]
  -- @param w [Number Width of the panel]
  -- @param h [Number Height of the panel]
  -- @return [Any Return anything but nil to replace the default drawing]
  if Theme.hook('PaintVendorRow', self, w, h) != nil then return end

  local padding = math.scale(8)
  local name_font = Theme.get_font('main_menu_small')
  local info_font = Theme.get_font('tooltip_small')
  local text_color = Theme.get_color('text')
  local price_w, price_h = util.text_size(self.price, name_font)
  local text_x = self.icon.x + self.icon:GetWide() + padding
  local price_x = self.button.x - padding - price_w
  local screen_x, screen_y = self:LocalToScreen(0, 0)

  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(self:IsHovered() and 220 or 180))
  draw.SimpleText(self.price, name_font, price_x, h * 0.5 - price_h * 0.5, Theme.get_color('accent_light'))

  render.SetScissorRect(screen_x + text_x, screen_y, screen_x + price_x - padding, screen_y + h, true)
    draw.SimpleText(self.name, name_font, text_x, math.scale(6), text_color)
    draw.SimpleText(self.info, info_font, text_x, h * 0.5 + math.scale(2), text_color:darken(40))
  render.SetScissorRect(0, 0, 0, 0, false)
end

--- Fills the row.
-- @param data [Map what the row shows: name, info (the line below the name) and price
--   (String), tooltip (String), model (String) and skin (Number) of the icon, button_text
--   (String) and on_click (Function called when the button is pressed)]
function PANEL:set_row(data)
  self.name = data.name or ''
  self.info = data.info or ''
  self.price = data.price or ''

  self.icon:SetModel(data.model, data.skin or 0)
  self.button:set_text(data.button_text or '')
  self.button.DoClick = function(btn)
    surface.PlaySound(Theme.get_sound('button_click_success_sound', 'garrysmod/ui_click.wav'))

    data.on_click()
  end

  if data.tooltip and data.tooltip != '' then
    self:SetTooltip(data.tooltip)
  end
end

vgui.Register('fl_vendor_row', PANEL, 'fl_base_panel')

PANEL = {}
PANEL.title = ''
PANEL.empty_text = ''

--- Creates the scroll panel that holds the rows.
function PANEL:Init()
  self.rows = {}

  self.scroll = vgui.Create('DScrollPanel', self)
end

--- Places the scroll panel below the title.
-- @param w [Number]
-- @param h [Number]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(4)
  local header = math.scale(36)

  self.scroll:SetPos(padding, header)
  self.scroll:SetSize(w - padding * 2, h - header - padding)
end

--- Draws the background and the title of the list, and a note in place of the rows if there
-- are none.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  --- Lets the active theme draw a list of the trade panel of a vendor itself. Called on the
  -- client every frame for both lists.
  -- @param panel [Panel The `fl_vendor_list` panel; its `title` and `empty_text` fields hold
  --   its texts and `rows` the row panels]
  -- @param w [Number Width of the panel]
  -- @param h [Number Height of the panel]
  -- @return [Any Return anything but nil to replace the default drawing]
  if Theme.hook('PaintVendorList', self, w, h) != nil then return end

  local header = math.scale(36)
  local title = t(self.title)
  local title_font = Theme.get_font('main_menu_titles')
  local title_w, title_h = util.text_size(title, title_font)

  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('main_dark'):alpha(150))
  draw.SimpleText(title, title_font, math.scale(8), header * 0.5 - title_h * 0.5, Theme.get_color('text'))

  if #self.rows == 0 then
    local text = t(self.empty_text)
    local font = Theme.get_font('main_menu_small')
    local text_w, text_h = util.text_size(text, font)

    draw.SimpleText(text, font, w * 0.5 - text_w * 0.5, h * 0.5 - text_h * 0.5, Theme.get_color('text'):darken(60))
  end
end

--- Sets the title of the list and the note that is shown while it has no rows.
-- @param title [String text or language phrase]
-- @param empty_text [String text or language phrase]
function PANEL:set_texts(title, empty_text)
  self.title = title or ''
  self.empty_text = empty_text or ''
end

--- Removes every row of the list.
function PANEL:clear()
  self.scroll:Clear()
  self.rows = {}
end

--- Adds a row to the end of the list.
-- @param data [Map what the row shows, see the set_row function of fl_vendor_row]
-- @return [Panel the fl_vendor_row panel]
function PANEL:add_row(data)
  local row = vgui.Create('fl_vendor_row', self.scroll)
  row:set_row(data)

  table.insert(self.rows, row)

  return row
end

--- Returns how far the list is scrolled down.
-- @return [Number]
function PANEL:get_scroll()
  return self.scroll:GetVBar():GetScroll()
end

--- Scrolls the list.
-- @param offset [Number]
function PANEL:set_scroll(offset)
  self.scroll:GetVBar():SetScroll(offset)
end

vgui.Register('fl_vendor_list', PANEL, 'fl_base_panel')

PANEL = {}

--- Creates the frame with the description of the vendor and the two lists.
function PANEL:Init()
  self:SetSize(math.min(math.scale(960), ScrW() - 32), math.min(math.scale(640), ScrH() - 32))
  self:Center()
  self:MakePopup()
  self:SetTitle('ui.vendor.title')

  self.opened_at = RealTime()

  self.description = vgui.Create('DLabel', self)
  self.description:SetFont(Theme.get_font('main_menu_small'))
  self.description:SetTextColor(Theme.get_color('text'))
  self.description:SetContentAlignment(7)
  self.description:SetWrap(true)
  self.description:SetText('')

  self.sell_list = vgui.Create('fl_vendor_list', self)
  self.sell_list:set_texts('ui.vendor.sells', 'ui.vendor.sells_nothing')

  self.buy_list = vgui.Create('fl_vendor_list', self)
  self.buy_list:set_texts('ui.vendor.buys', 'ui.vendor.buys_nothing')
end

--- Places the description at the top and the two lists side by side below it, leaving room
-- for the line about money at the bottom.
-- @param w [Number]
-- @param h [Number]
function PANEL:PerformLayout(w, h)
  self.BaseClass.PerformLayout(self, w, h)

  local left, top, right, bottom = self:GetDockPadding()
  local gap = math.scale(8)
  local header = self.description:GetText() != '' and math.scale(44) or 0
  local footer = math.scale(32)
  local list_w = (w - left - right - gap) * 0.5
  local list_y = top + header + (header > 0 and gap or 0)
  local list_h = h - list_y - bottom - footer

  self.description:SetPos(left + gap, top)
  self.description:SetSize(w - left - right - gap * 2, header)

  self.sell_list:SetPos(left, list_y)
  self.sell_list:SetSize(list_w, list_h)

  self.buy_list:SetPos(left + list_w + gap, list_y)
  self.buy_list:SetSize(list_w, list_h)
end

--- Draws how much money the local player has and, if its money pool is finite, how much the
-- vendor has.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  local data = self.data

  if !data or !IsValid(PLAYER) then return end

  local left, top, right, bottom = self:GetDockPadding()
  local gap = math.scale(8)
  local font = Theme.get_font('main_menu_small')
  local color = Theme.get_color('text')
  local own_money = Vendors:format_money(PLAYER:get_money(data.currency), data.currency)
  local text = t'ui.vendor.your_money'..': '..own_money
  local text_w, text_h = util.text_size(text, font)
  local y = h - bottom - math.scale(16) - text_h * 0.5

  draw.SimpleText(text, font, left + gap, y, color)

  if data.money then
    text = t'ui.vendor.vendor_money'..': '..Vendors:format_money(data.money, data.currency)
    text_w = util.text_size(text, font)

    draw.SimpleText(text, font, w - right - gap - text_w, y, color)
  end
end

--- Closes the panel when TAB or E is pressed, except right after it has opened, when the
-- use key that opened it may still be held.
-- @param key [Number KEY_ enumerator]
function PANEL:OnKeyCodePressed(key)
  if RealTime() - self.opened_at < 0.3 then return end

  if key == KEY_TAB or key == KEY_E then
    self:safe_remove()
  end
end

--- Tells the server that the trade is over, unless it was the server that closed the panel.
function PANEL:OnRemove()
  timer.Remove('fl_vendor_refresh')

  if !self.closed_by_server then
    Cable.send('fl_vendor_close')
  end
end

--- Removes the panel.
-- @param by_server=false [Boolean true if the server has ended the trade, so that it is not
--   told about it]
function PANEL:close(by_server)
  self.closed_by_server = by_server

  self:safe_remove()
end

--- Sets the vendor that the panel trades with and what it shows.
-- @param vendor [Entity]
-- @param data [Map trade data sent by the server: name, description, currency, money, sells
--   (List of { id, price, stock }) and buys (List of { instance_id, price })]
function PANEL:set_vendor(vendor, data)
  self.vendor = vendor

  self:set_data(data)
end

--- Returns the vendor that the panel trades with.
-- @return [Entity]
function PANEL:get_vendor()
  return self.vendor
end

--- Replaces what the panel shows and rebuilds its lists.
-- @param data [Map trade data sent by the server, see set_vendor]
function PANEL:set_data(data)
  self.data = data

  self:SetTitle(data.name or 'ui.vendor.title')
  self.description:SetText(data.description or '')

  self:rebuild()
  self:InvalidateLayout()
end

--- Fills the list of what the vendor sells and the list of what it buys from the local
-- player, where items of the same kind that fetch the same price share a row.
function PANEL:rebuild()
  local data = self.data

  if !data then return end

  local currency = data.currency
  local sell_scroll, buy_scroll = self.sell_list:get_scroll(), self.buy_list:get_scroll()
  local sells = {}
  local buys = {}
  local groups = {}

  self.sell_list:clear()
  self.buy_list:clear()

  for k, v in ipairs(data.sells or {}) do
    local item_table = Item.find_by_id(v.id)

    if item_table then
      table.insert(sells, { name = t(item_table:get_name()), item_table = item_table, entry = v })
    end
  end

  for k, v in ipairs(data.buys or {}) do
    local item_obj = Item.find_instance_by_id(v.instance_id)

    if item_obj then
      local name = t(item_obj:get_name())
      local key = item_obj.id..'\n'..name..'\n'..tostring(v.price)

      if !groups[key] then
        groups[key] = { name = name, item_obj = item_obj, price = v.price, instance_ids = {} }

        table.insert(buys, groups[key])
      end

      table.insert(groups[key].instance_ids, v.instance_id)
    end
  end

  table.SortByMember(sells, 'name', true)
  table.SortByMember(buys, 'name', true)

  for k, v in ipairs(sells) do
    local item_table, entry = v.item_table, v.entry
    local info = ''

    if entry.stock then
      info = entry.stock > 0 and t('ui.vendor.stock', { count = entry.stock }) or t'ui.vendor.sold_out'
    end

    self.sell_list:add_row({
      name = v.name,
      info = info,
      price = Vendors:format_money(entry.price, currency),
      tooltip = t(item_table:get_description()),
      model = item_table:get_model(),
      skin = item_table:get_skin(),
      button_text = t'ui.vendor.buy',
      on_click = function()
        Cable.send('fl_vendor_buy', self.vendor, entry.id)
      end
    })
  end

  for k, v in ipairs(buys) do
    local item_obj = v.item_obj

    self.buy_list:add_row({
      name = v.name,
      info = t('ui.vendor.owned', { count = #v.instance_ids }),
      price = Vendors:format_money(v.price, currency),
      tooltip = t(item_obj:get_description()),
      model = item_obj:get_model(),
      skin = item_obj:get_skin(),
      button_text = t'ui.vendor.sell',
      on_click = function()
        Cable.send('fl_vendor_sell', self.vendor, v.instance_ids[1])
      end
    })
  end

  self.sell_list:set_scroll(sell_scroll)
  self.buy_list:set_scroll(buy_scroll)
end

vgui.Register('fl_vendor_trade', PANEL, 'fl_frame')
