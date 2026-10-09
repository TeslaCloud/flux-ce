--- The door management menu (`fl_door_management`) of the owner of a door and of those who
-- manage it: a text entry for the text on the door, a list of the characters that have or
-- can be given access, and for the owner a button to sell the door. Every change is sent to
-- the server at once, and the server answers with the new state of the door.

local PANEL = {}

--- Sets up the frame with the summary, the text entry, the access list and the sell button.
-- Only one management menu is open at a time.
function PANEL:Init()
  if IsValid(Doors.management) then
    Doors.management:Remove()
  end

  Doors.management = self

  local margin = math.scale(4)
  local column_name = t'ui.door.management.character'
  local column_access = t'ui.door.management.access'

  self:SetSize(math.scale(420), math.scale(520))
  self:Center()
  self:SetTitle(t'ui.door.management.title')

  self:MakePopup()

  self.info = {}

  self.owner_label = vgui.Create('DLabel', self)
  self.owner_label:Dock(TOP)
  self.owner_label:SetText('')

  self.group_label = vgui.Create('DLabel', self)
  self.group_label:Dock(TOP)
  self.group_label:SetText(t'ui.door.management.group')
  self.group_label:SetWrap(true)
  self.group_label:SetAutoStretchVertical(true)
  self.group_label:SetVisible(false)

  self.text_row = vgui.Create('DPanel', self)
  self.text_row:Dock(TOP)
  self.text_row:DockMargin(0, margin, 0, margin)
  self.text_row:SetTall(math.scale(24))
  self.text_row:SetPaintBackground(false)
  self.text_row.Think = function(pnl)
    self:check_door()
  end

  self.text_save = vgui.Create('DButton', self.text_row)
  self.text_save:Dock(RIGHT)
  self.text_save:DockMargin(margin, 0, 0, 0)
  self.text_save:SetWide(math.scale(96))
  self.text_save:SetText(t'ui.door.management.save')
  self.text_save.DoClick = function(btn)
    self:save_text()
  end

  self.text_entry = vgui.Create('DTextEntry', self.text_row)
  self.text_entry:Dock(FILL)
  self.text_entry:SetPlaceholderText(t'ui.door.management.text')
  self.text_entry.OnEnter = function(pnl)
    self:save_text()
  end

  self.sell = vgui.Create('DButton', self)
  self.sell:Dock(BOTTOM)
  self.sell:DockMargin(0, margin, 0, 0)
  self.sell:SetTall(math.scale(28))
  self.sell:SetVisible(false)
  self.sell.DoClick = function(btn)
    self:confirm_sell()
  end

  self.hint = vgui.Create('DLabel', self)
  self.hint:Dock(BOTTOM)
  self.hint:SetText(t'ui.door.management.hint')
  self.hint:SetWrap(true)
  self.hint:SetAutoStretchVertical(true)

  self.access_list = vgui.Create('DListView', self)
  self.access_list:Dock(FILL)
  self.access_list:SetMultiSelect(false)
  self.access_list:AddColumn(column_name)
  self.access_list:AddColumn(column_access)
  self.access_list.OnRowRightClick = function(pnl, line_id, line)
    self:open_access_menu(line)
  end

  self.access_list.DoDoubleClick = function(pnl, line_id, line)
    self:open_access_menu(line)
  end
end

--- Closes the menu when F3 is pressed.
-- @param key [Number key code]
function PANEL:OnKeyCodePressed(key)
  if key == KEY_F3 then
    self:safe_remove()
  end
end

--- Closes the menu when the door is gone or the player has walked away from it. Runs every
-- frame from the Think of the text row, so that the Think of the frame itself, which moves
-- and resizes it, stays as it is.
function PANEL:check_door()
  local door = self.door

  if door == nil then return end

  if !IsValid(door) or !IsValid(PLAYER) or PLAYER:GetPos():Distance(door:GetPos()) > Doors.use_distance then
    self:safe_remove()
  end
end

--- Closes the menus that were opened from this one and forgets the menu.
function PANEL:OnRemove()
  CloseDermaMenus()

  if Doors.management == self then
    Doors.management = nil
  end
end

--- Sets the door to manage and what the server has told about it.
-- @param entity [Entity the door]
-- @param info [Map the state of the door, see `Doors:get_menu_info`]
function PANEL:set_door(entity, info)
  self.door = entity

  self:set_info(info)
end

--- Returns the door that is being managed.
-- @return [Entity the door, or nil if it has not been set yet]
function PANEL:get_door()
  return self.door
end

--- Returns what the server has last told about the door.
-- @return [Map the state of the door, see `Doors:get_menu_info`]
function PANEL:get_info()
  return self.info
end

--- Updates the menu with the state of the door that the server has sent. The menu closes
-- if the player does not manage the door anymore.
-- @param info [Map the state of the door, see `Doors:get_menu_info`]
function PANEL:set_info(info)
  info = istable(info) and info or {}

  self.info = info

  local level = info.level or DOOR_ACCESS_NONE

  if level < DOOR_ACCESS_MANAGE then
    self:safe_remove()

    return
  end

  local is_owner = level >= DOOR_ACCESS_OWNER
  local owner_text = t'ui.door.management.you_own'

  if !is_owner then
    owner_text = t('ui.door.management.owner', { name = info.owner_name or '' })
  end

  self.owner_label:SetText(owner_text)
  self.group_label:SetVisible((info.group_size or 1) > 1)

  if self.text_pending or vgui.GetKeyboardFocus() != self.text_entry then
    self.text_entry:SetText(info.text or '')

    self.text_pending = nil
  end

  local refund_text = Doors:format_price(info.refund, info.refund_currency)
  local sell_text = t'ui.door.management.abandon'

  if refund_text then
    sell_text = t('ui.door.management.sell', { price = refund_text })
  end

  self.sell:SetText(sell_text)
  self.sell:SetVisible(is_owner)

  self:InvalidateLayout()
  self:rebuild()
end

--- Returns the name of an access level.
-- @param level [Number DOOR_ACCESS_NONE, DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE]
-- @return [String]
function PANEL:get_level_name(level)
  local name = t'ui.door.access.none'

  if level == DOOR_ACCESS_MANAGE then
    name = t'ui.door.access.manage'
  elseif level == DOOR_ACCESS_USE then
    name = t'ui.door.access.use'
  end

  return name
end

--- Fills the list with the characters that have access to the door, followed by the
-- characters of the other players on the server, which can be given access.
function PANEL:rebuild()
  local info = self.info
  local owner_id = IsValid(self.door) and Doors:get_owner_id(self.door) or nil
  local own_id = Doors:get_character_id(PLAYER)
  local online = {}
  local listed = {}
  local rows = {}

  for k, v in ipairs(player.GetAll()) do
    local character_id = Doors:get_character_id(v)

    if character_id then
      online[character_id] = v
    end
  end

  for k, v in ipairs(info.access or {}) do
    local target = online[v.id]
    local name = v.name or ''

    if IsValid(target) then
      name = target:name()
    else
      name = t('ui.door.management.away', { name = name })
    end

    listed[v.id] = true

    table.insert(rows, { id = v.id, name = name, level = v.level or DOOR_ACCESS_USE })
  end

  for character_id, target in pairs(online) do
    if !listed[character_id] and character_id != owner_id and character_id != own_id then
      table.insert(rows, { id = character_id, name = target:name(), level = DOOR_ACCESS_NONE })
    end
  end

  table.sort(rows, function(a, b)
    if a.level != b.level then
      return a.level > b.level
    end

    if a.name != b.name then
      return a.name < b.name
    end

    return a.id < b.id
  end)

  self.access_list:Clear()

  for k, v in ipairs(rows) do
    local level_name = self:get_level_name(v.level)
    local line = self.access_list:AddLine(v.name, level_name)

    line.character_id = v.id
    line.level = v.level
  end
end

--- Opens the menu with the access changes that the player may make for the character of a
-- row: the owner may set any level, those who manage the door may only give and take the
-- level that lets a character lock and unlock it.
-- @param line [Panel the row of the character in the list]
function PANEL:open_access_menu(line)
  if !IsValid(line) or !line.character_id then return end

  local is_owner = (self.info.level or DOOR_ACCESS_NONE) >= DOOR_ACCESS_OWNER
  local character_id = line.character_id
  local level = line.level or DOOR_ACCESS_NONE
  local menu = DermaMenu()
  local options = 0

  if level != DOOR_ACCESS_USE and (is_owner or level != DOOR_ACCESS_MANAGE) then
    menu:AddOption(t'ui.door.access.give_use', function()
      self:set_access(character_id, DOOR_ACCESS_USE)
    end)

    options = options + 1
  end

  if level != DOOR_ACCESS_MANAGE and is_owner then
    menu:AddOption(t'ui.door.access.give_manage', function()
      self:set_access(character_id, DOOR_ACCESS_MANAGE)
    end)

    options = options + 1
  end

  if level != DOOR_ACCESS_NONE and (is_owner or level != DOOR_ACCESS_MANAGE) then
    menu:AddOption(t'ui.door.access.take', function()
      self:set_access(character_id, DOOR_ACCESS_NONE)
    end)

    options = options + 1
  end

  if options < 1 then
    menu:Remove()

    return
  end

  menu:Open()
end

--- Asks the server to change the access of a character to the door.
-- @param character_id [Number ID of the character]
-- @param level [Number DOOR_ACCESS_NONE, DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE]
function PANEL:set_access(character_id, level)
  if !IsValid(self.door) then return end

  Cable.send('fl_door_set_access', self.door, character_id, level)
end

--- Asks the server to put the text of the text entry on the door.
function PANEL:save_text()
  if !IsValid(self.door) then return end

  self.text_pending = true

  Cable.send('fl_door_set_text', self.door, self.text_entry:GetValue())
end

--- Asks the player to confirm the sale of the door, then asks the server to sell it and
-- closes the menu.
function PANEL:confirm_sell()
  local refund_text = Doors:format_price(self.info.refund, self.info.refund_currency)
  local title = t'ui.door.management.sell_title'
  local message = t'ui.door.management.abandon_message'
  local yes, no = t'ui.yes', t'ui.no'

  if refund_text then
    message = t('ui.door.management.sell_message', { price = refund_text })
  end

  Derma_Query(message, title, yes, function()
    if !IsValid(self) or !IsValid(self.door) then return end

    Cable.send('fl_door_sell', self.door)

    self:safe_remove()
  end, no)
end

vgui.Register('fl_door_management', PANEL, 'DFrame')
