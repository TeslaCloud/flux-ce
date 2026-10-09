--- The vendor editor (`fl_vendor_editor`): a frame with four pages for the settings of a
-- vendor. The first has its name, description, model, animation, currency, money pool and
-- buy-back rate; the second lists every item, where a click on a row chooses whether the
-- vendor sells or buys the item, at what price and with how much stock; the third picks the
-- factions and classes that may trade; the fourth holds the phrases of the vendor.
-- The server opens the editor for staff with the 'manage_vendors' permission who use the
-- Vendor Tool on a vendor, and gets the settings back when the save button is pressed.

local PANEL = {}

--- Turns the text of an entry into a number.
-- @param text [String]
-- @return [Number the number, or false if the text is empty or not a number of 0 or more]
local function to_amount(text)
  local value = tonumber(text)

  if !value or value != value or value < 0 or value == math.huge then
    return false
  end

  return value
end

--- Creates the frame, its save and remove buttons, the bar of page buttons and the body
-- that holds the pages.
function PANEL:Init()
  local gap = math.scale(4)
  local font = Theme.get_font('main_menu_small')

  self:SetSize(math.min(math.scale(760), ScrW() - 32), math.min(math.scale(680), ScrH() - 32))
  self:Center()
  self:MakePopup()
  self:set_draggable(true)
  self:SetTitle('ui.vendor.editor.title')

  self.pages = {}

  self.footer = vgui.Create('DPanel', self)
  self.footer:SetPaintBackground(false)
  self.footer:SetTall(math.scale(32))
  self.footer:DockMargin(0, gap, 0, 0)
  self.footer:Dock(BOTTOM)

  self.save_button = vgui.Create('fl_button', self.footer)
  self.save_button:SetWide(math.scale(180))
  self.save_button:Dock(RIGHT)
  self.save_button:SetFont(font)
  self.save_button:set_text(t'ui.vendor.editor.save')
  self.save_button:set_icon('fa-check')
  self.save_button:set_centered(true)
  self.save_button:set_draw_outline(true)
  self.save_button:set_background_color(Theme.get_color('accent'))
  self.save_button.DoClick = function(btn)
    self:save()
  end

  self.remove_button = vgui.Create('fl_button', self.footer)
  self.remove_button:SetWide(math.scale(180))
  self.remove_button:Dock(LEFT)
  self.remove_button:SetFont(font)
  self.remove_button:set_text(t'ui.vendor.editor.remove')
  self.remove_button:set_icon('fa-trash')
  self.remove_button:set_centered(true)
  self.remove_button:set_draw_outline(true)
  self.remove_button:set_background_color(Theme.get_color('main'))
  self.remove_button.DoClick = function(btn)
    Derma_Query(
      t'ui.vendor.editor.remove_message',
      t'ui.vendor.editor.remove',
      t'ui.yes',
      function()
        if IsValid(self) then
          Cable.send('fl_vendor_remove', self.vendor)

          self:safe_remove()
        end
      end,
      (t'ui.no')
    )
  end

  self.tabs = vgui.Create('DPanel', self)
  self.tabs:SetPaintBackground(false)
  self.tabs:SetTall(math.scale(32))
  self.tabs:DockMargin(0, 0, 0, gap * 2)
  self.tabs:Dock(TOP)

  self.body = vgui.Create('DPanel', self)
  self.body:SetPaintBackground(false)
  self.body:Dock(FILL)
  self.body.PerformLayout = function(pnl, w, h)
    for k, v in pairs(self.pages) do
      v.panel:SetPos(0, 0)
      v.panel:SetSize(w, h)
    end
  end
end

--- Sets the vendor to edit and builds the pages out of its settings.
-- @param vendor [Entity]
-- @param data [Map vendor settings sent by the server]
function PANEL:set_vendor(vendor, data)
  self.vendor = vendor
  self.data = table.Copy(data)

  self.data.sells = istable(self.data.sells) and self.data.sells or {}
  self.data.buys = istable(self.data.buys) and self.data.buys or {}
  self.data.factions = istable(self.data.factions) and self.data.factions or {}
  self.data.classes = istable(self.data.classes) and self.data.classes or {}
  self.data.phrases = istable(self.data.phrases) and self.data.phrases or {}

  self:build_general()
  self:build_items()
  self:build_access()
  self:build_phrases()
  self:show_page('general')
end

--- Returns the vendor that is being edited.
-- @return [Entity]
function PANEL:get_vendor()
  return self.vendor
end

--- Adds a page to the editor along with the button that shows it.
-- @param id [String ID of the page]
-- @param title [String translated title of the page]
-- @param class='DScrollPanel' [String class of the panel that holds the page]
-- @return [Panel the panel of the page]
function PANEL:add_page(id, title, class)
  local panel = vgui.Create(class or 'DScrollPanel', self.body)
  panel:SetVisible(false)

  local button = vgui.Create('fl_button', self.tabs)
  button:SetWide(math.scale(150))
  button:DockMargin(0, 0, math.scale(4), 0)
  button:Dock(LEFT)
  button:SetFont(Theme.get_font('main_menu_small'))
  button:set_text(title)
  button:set_centered(true)
  button:set_draw_outline(true)
  button:set_background_color(Theme.get_color('main'))
  button.DoClick = function(btn)
    self:show_page(id)
  end

  self.pages[id] = { panel = panel, button = button }

  return panel
end

--- Shows one page of the editor and hides the others.
-- @param id [String ID of the page]
function PANEL:show_page(id)
  for k, v in pairs(self.pages) do
    v.panel:SetVisible(k == id)
    v.button:set_active(k == id)
    v.button:set_background_color(Theme.get_color(k == id and 'accent' or 'main'))
  end

  self.body:InvalidateLayout()
end

--- Adds a labelled control to a page.
-- @param page [Panel the panel of the page]
-- @param title [String translated label]
-- @param class [String class of the control, such as 'DTextEntry' or 'DComboBox']
-- @return [Panel the control]
function PANEL:add_field(page, title, class)
  local row = vgui.Create('DPanel', page)
  row:SetPaintBackground(false)
  row:SetTall(math.scale(28))
  row:DockMargin(0, 0, 0, math.scale(4))
  row:Dock(TOP)

  local label = vgui.Create('DLabel', row)
  label:SetWide(math.scale(260))
  label:Dock(LEFT)
  label:SetFont(Theme.get_font('main_menu_small'))
  label:SetTextColor(Theme.get_color('text'))
  label:SetText(title)

  local control = vgui.Create(class, row)
  control:Dock(FILL)

  return control
end

--- Adds a line of explanation to a page.
-- @param page [Panel the panel of the page]
-- @param text [String translated text]
-- @return [Panel the label]
function PANEL:add_help(page, text)
  local label = vgui.Create('DLabel', page)
  label:DockMargin(0, 0, 0, math.scale(8))
  label:Dock(TOP)
  label:SetFont(Theme.get_font('tooltip_small'))
  label:SetTextColor(Theme.get_color('text'):darken(50))
  label:SetText(text)
  label:SetWrap(true)
  label:SetAutoStretchVertical(true)

  return label
end

--- Adds a checkbox to a page.
-- @param page [Panel the panel of the page]
-- @param title [String translated label]
-- @param checked [Boolean whether the checkbox starts out checked]
-- @param callback [Function called with the new state (Boolean) when it changes]
-- @return [Panel the checkbox]
function PANEL:add_check_box(page, title, checked, callback)
  local check_box = vgui.Create('DCheckBoxLabel', page)
  check_box:DockMargin(0, 0, 0, math.scale(6))
  check_box:Dock(TOP)
  check_box:SetText(title)
  check_box:SetTextColor(Theme.get_color('text'))
  check_box:SetChecked(checked)
  check_box.OnChange = function(pnl, value)
    callback(value)
  end

  return check_box
end

--- Builds the page with the name, description, model, animation, currency, money pool and
-- buy-back rate of the vendor.
function PANEL:build_general()
  local data = self.data
  local page = self:add_page('general', (t'ui.vendor.editor.general'))

  self.name_entry = self:add_field(page, t'ui.vendor.editor.name', 'DTextEntry')
  self.name_entry:SetText(tostring(data.name or ''))

  self.description_entry = self:add_field(page, t'ui.vendor.editor.description', 'DTextEntry')
  self.description_entry:SetText(tostring(data.description or ''))

  self.model_entry = self:add_field(page, t'ui.vendor.editor.model', 'DTextEntry')
  self.model_entry:SetText(tostring(data.model or ''))

  self.animation_box = self:add_field(page, t'ui.vendor.editor.animation', 'DComboBox')
  self.animation_box.OnSelect = function(pnl, index, text, value)
    data.animation = value
  end

  self.animation_box:AddChoice(t'ui.vendor.editor.animation_auto', '', data.animation == '')

  if IsValid(self.vendor) then
    for i = 0, self.vendor:GetSequenceCount() - 1 do
      local name = self.vendor:GetSequenceName(i)

      self.animation_box:AddChoice(name, name, data.animation == name)
    end
  end

  self:add_help(page, t'ui.vendor.editor.animation_help')

  self.currency_box = self:add_field(page, t'ui.vendor.editor.currency', 'DComboBox')
  self.currency_box.OnSelect = function(pnl, index, text, value)
    data.currency = value

    self:refresh_items()
  end

  for id, currency_data in SortedPairs(Currencies:all()) do
    self.currency_box:AddChoice(t(currency_data.name), id, data.currency == id)
  end

  self.money_entry = self:add_field(page, t'ui.vendor.editor.money', 'DTextEntry')
  self.money_entry:SetNumeric(true)
  self.money_entry:SetText(data.money and tostring(data.money) or '')

  self:add_help(page, t'ui.vendor.editor.money_help')

  self.rate_entry = self:add_field(page, t'ui.vendor.editor.buy_rate', 'DTextEntry')
  self.rate_entry:SetNumeric(true)
  self.rate_entry:SetText(tostring(data.buy_rate or 0))
  self.rate_entry.OnChange = function(pnl)
    data.buy_rate = to_amount(pnl:GetText()) or data.buy_rate

    self:refresh_items()
  end

  self:add_help(page, t'ui.vendor.editor.buy_rate_help')
end

--- Builds the page with the list of items and its search field.
function PANEL:build_items()
  local page = self:add_page('items', t'ui.vendor.editor.items', 'DPanel')
  page:SetPaintBackground(false)

  self.search_entry = vgui.Create('DTextEntry', page)
  self.search_entry:SetTall(math.scale(28))
  self.search_entry:DockMargin(0, 0, 0, math.scale(4))
  self.search_entry:Dock(TOP)
  self.search_entry:SetPlaceholderText(t'ui.vendor.editor.search')
  self.search_entry:SetUpdateOnType(true)
  self.search_entry.OnValueChange = function(pnl, value)
    self:refresh_items()
  end

  local help = self:add_help(page, t'ui.vendor.editor.items_help')
  help:DockMargin(0, math.scale(4), 0, 0)
  help:Dock(BOTTOM)

  self.item_list = vgui.Create('DListView', page)
  self.item_list:Dock(FILL)
  self.item_list:SetMultiSelect(false)
  self.item_list:AddColumn((t'ui.vendor.editor.item'))
  self.item_list:AddColumn((t'ui.vendor.editor.sell_price'))
  self.item_list:AddColumn((t'ui.vendor.editor.stock'))
  self.item_list:AddColumn((t'ui.vendor.editor.buy_price'))
  self.item_list.OnRowSelected = function(pnl, line_id, line)
    self:open_item_menu(line.item_id)
  end

  self.item_list.OnRowRightClick = function(pnl, line_id, line)
    self:open_item_menu(line.item_id)
  end

  self:refresh_items()
end

--- Fills the list of items again: every item whose name or ID matches the search, with what
-- the vendor sells it for, how many it has and what it buys it for.
function PANEL:refresh_items()
  if !IsValid(self.item_list) then return end

  local data = self.data
  local query = self.search_entry:GetText():utf8lower()
  local buy_rate = tonumber(data.buy_rate) or 0
  local items = {}

  self.item_list:Clear()

  for id, item_table in pairs(Item.all()) do
    local name = t(item_table:get_real_name())

    if !item_table.is_base and (query == '' or name:utf8lower():find(query, 1, true) or id:find(query, 1, true)) then
      table.insert(items, { id = id, name = name, cost = tonumber(item_table.cost) or 0 })
    end
  end

  table.SortByMember(items, 'name', true)

  for k, v in ipairs(items) do
    local sells, buys = data.sells[v.id], data.buys[v.id]
    local sell_price, stock, buy_price = '', '', ''

    if sells then
      sell_price = Vendors:format_money(sells.price or v.cost, data.currency)
      stock = sells.stock and tostring(sells.stock) or t'ui.vendor.editor.unlimited'

      if !sells.price then
        sell_price = sell_price..' '..t'ui.vendor.editor.by_default'
      end
    end

    if buys then
      buy_price = Vendors:format_money(buys.price or math.Round(v.cost * buy_rate / 100, 2), data.currency)

      if !buys.price then
        buy_price = buy_price..' '..t'ui.vendor.editor.by_default'
      end
    end

    self.item_list:AddLine(v.name, sell_price, stock, buy_price).item_id = v.id
  end
end

--- Asks for a number and stores it in a field of an item entry. An empty answer stores
-- false, which stands for the default price or for unlimited stock.
-- @param entry [Map the entry of the item in the sells or the buys list]
-- @param field [String 'price' or 'stock']
-- @param message [String translated text of the request]
function PANEL:request_amount(entry, field, message)
  Derma_StringRequest(
    t'ui.vendor.editor.title',
    message,
    entry[field] and tostring(entry[field]) or '',
    function(text)
      if !IsValid(self) then return end

      local value = to_amount(text)

      if value and field == 'stock' then
        value = math.floor(value)
      end

      entry[field] = value

      self:refresh_items()
    end
  )
end

--- Opens the menu of an item of the list: whether the vendor sells it and buys it, and the
-- price and stock to set.
-- @param item_id [String]
function PANEL:open_item_menu(item_id)
  if !isstring(item_id) then return end

  local data = self.data
  local sells, buys = data.sells[item_id], data.buys[item_id]
  local options = DermaMenu()

  if sells then
    options:AddOption(t'ui.vendor.editor.stop_selling', function()
      data.sells[item_id] = nil

      self:refresh_items()
    end):SetIcon('icon16/cart_delete.png')

    options:AddOption(t'ui.vendor.editor.set_sell_price', function()
      self:request_amount(sells, 'price', t'ui.vendor.editor.price_message')
    end):SetIcon('icon16/money.png')

    options:AddOption(t'ui.vendor.editor.set_stock', function()
      self:request_amount(sells, 'stock', t'ui.vendor.editor.stock_message')
    end):SetIcon('icon16/package.png')
  else
    options:AddOption(t'ui.vendor.editor.start_selling', function()
      data.sells[item_id] = { price = false, stock = false }

      self:refresh_items()
    end):SetIcon('icon16/cart_add.png')
  end

  options:AddSpacer()

  if buys then
    options:AddOption(t'ui.vendor.editor.stop_buying', function()
      data.buys[item_id] = nil

      self:refresh_items()
    end):SetIcon('icon16/basket_delete.png')

    options:AddOption(t'ui.vendor.editor.set_buy_price', function()
      self:request_amount(buys, 'price', t'ui.vendor.editor.price_message')
    end):SetIcon('icon16/money.png')
  else
    options:AddOption(t'ui.vendor.editor.start_buying', function()
      data.buys[item_id] = { price = false }

      self:refresh_items()
    end):SetIcon('icon16/basket_add.png')
  end

  options:Open()
end

--- Builds the page with a checkbox for every faction and, if the Classes plugin is loaded,
-- for every class. A faction or a class that the vendor is limited to but that is not
-- registered anymore gets a checkbox labelled with its ID, so that it can be unchecked.
function PANEL:build_access()
  local data = self.data
  local page = self:add_page('access', (t'ui.vendor.editor.access'))

  self:add_help(page, t'ui.vendor.editor.access_help')

  if Factions then
    local factions = Factions.all()

    for id, faction_table in SortedPairs(factions) do
      self:add_check_box(page, t(faction_table:get_name()), data.factions[id] == true, function(value)
        data.factions[id] = value and true or nil
      end)
    end

    for id, listed in SortedPairs(table.Copy(data.factions)) do
      if !factions[id] then
        self:add_check_box(page, tostring(id), true, function(value)
          data.factions[id] = value and true or nil
        end)
      end
    end
  end

  if Classes then
    local classes = Classes.all()

    for id, class_table in SortedPairs(classes) do
      local faction_table = class_table:get_faction()
      local title = t(class_table:get_name())

      if faction_table then
        title = t(faction_table:get_name())..': '..title
      end

      self:add_check_box(page, title, data.classes[id] == true, function(value)
        data.classes[id] = value and true or nil
      end)
    end

    for id, listed in SortedPairs(table.Copy(data.classes)) do
      if !classes[id] then
        self:add_check_box(page, tostring(id), true, function(value)
          data.classes[id] = value and true or nil
        end)
      end
    end
  end
end

--- Builds the page with an entry for every phrase of the vendor. The default phrase is shown
-- in an entry that is left empty.
function PANEL:build_phrases()
  local data = self.data
  local page = self:add_page('phrases', (t'ui.vendor.editor.phrases.title'))

  self.phrase_entries = {}

  self:add_help(page, t'ui.vendor.editor.phrases.help')

  for k, v in ipairs(Vendors.phrases) do
    local entry = self:add_field(page, t('ui.vendor.editor.phrases.'..v), 'DTextEntry')
    entry:SetPlaceholderText(t('vendor.phrase.'..v))
    entry:SetText(tostring(data.phrases[v] or ''))

    self.phrase_entries[v] = entry
  end
end

--- Sends the settings to the server and closes the editor.
function PANEL:save()
  local data = self.data

  data.name = self.name_entry:GetText()
  data.description = self.description_entry:GetText()
  data.model = self.model_entry:GetText()
  data.money = to_amount(self.money_entry:GetText())
  data.buy_rate = to_amount(self.rate_entry:GetText()) or data.buy_rate

  for k, v in pairs(self.phrase_entries) do
    data.phrases[k] = v:GetText()
  end

  Cable.send('fl_vendor_save', self.vendor, data)

  self:safe_remove()
end

vgui.Register('fl_vendor_editor', PANEL, 'fl_frame')
