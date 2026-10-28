--- Permission editor of the admin panel's player management page, which sets the individual
-- and temporary permissions of the selected player, or those of the character the player has
-- loaded. A switch above the list picks which of the two is edited. Every row also names
-- what the player may do right now and which layer decides it: root access, the character
-- (temporary or lasting), the player (temporary or lasting) or the role, see
-- `Bolt:get_permission_layer`.

--- Returns the horizontal layout that the rows of the editor and the bulk buttons of the
-- categories share: the title comes first, then the three value buttons, then the column
-- that names the deciding layer.
-- @param w [Number width of the row]
-- @return [Number width of the title column, Number width of each value column]
local function get_columns(w)
  return w * 0.28, w * 0.17
end

--- The network messages that set each layer's values, by layer.
local layer_messages = {
  user = {
    set = 'fl_bolt_set_permission',
    temporary = 'fl_temp_permission',
    delete_temporary = 'fl_delete_temp_permission'
  },
  character = {
    set = 'fl_bolt_set_character_permission',
    temporary = 'fl_bolt_character_temp_permission',
    delete_temporary = 'fl_bolt_delete_character_temp_permission'
  }
}

--- A row of the permission editor: the name of a permission, the allow, not set and never
-- buttons that set its value for the edited player or their character, and what the player
-- may do now together with the layer that decides it. Right-clicking a button makes that
-- value temporary.
local PANEL = {}
PANEL.permission_value = PERM_NO
PANEL.permission = {}
PANEL.layer = 'user'

--- Recreates the row: the permission's title, the allow / not set / never buttons and the
-- label of the deciding layer. The name and the description of the permission are
-- translated if they are language phrases. Right-clicking the allow or never button asks for
-- a duration and makes that value temporary; right-clicking the not set button takes the
-- temporary value away. A duration that cannot be read is reported to the local player. The
-- children are positioned by `PerformLayout`, so the row may be resized afterwards.
function PANEL:rebuild()
  if IsValid(self.container) then
    self.container:safe_remove()
  end

  local font = Theme.get_font('text_small')
  local permission = self:get_permission()

  local paint_button = function(btn, w, h) Theme.call('PaintPermissionButton', self, btn, w, h) end
  local request_temporary = function(btn)
    local messages = layer_messages[self.layer]

    surface.PlaySound('buttons/button14.wav')

    if btn.perm_value == PERM_NO then
      Cable.send(messages.delete_temporary, self:get_player(), self:get_permission().id)

      self:set_temporary(PERM_NO, 0)

      return
    end

    Derma_StringRequest(t'ui.admin.temp_permission.title',
      t'ui.admin.temp_permission.message',
      '',
      function(text)
        local duration = Bolt:interpret_ban_time(text)
        local perm_id = self:get_permission().id
        local perm_value = btn.perm_value

        if text == '' then
          Cable.send(messages.delete_temporary, self:get_player(), perm_id)

          self:set_temporary(perm_value, 0)

          return
        end

        if !Bolt:is_temp_duration(duration) then
          PLAYER:notify('error.invalid_time', { time = text })

          return
        end

        Cable.send(messages.temporary, self:get_player(), perm_id, perm_value, duration)

        self:set_temporary(perm_value, os.time() + duration)
      end)
  end

  self.container = vgui.Create('fl_base_panel', self)
  self.container:Dock(FILL)

  self.title = vgui.Create('DLabel', self.container)
  self.title:SetFont(font)
  self.title:SetTextColor(Theme.get_color('text'))
  self.title:SetText(t(permission.name or 'No Permission'))

  if permission.description then
    self.title:SetTooltip(t(permission.description))
  end

  self.button_allow = vgui.Create('DButton', self.container)
  self.button_allow:SetText('')
  self.button_allow.perm_value = PERM_ALLOW
  self.button_allow.Paint = paint_button
  self.button_allow.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('buttons/button14.wav')
    self:select_button(btn)
  end

  self.button_allow.DoRightClick = request_temporary

  self.button_no = vgui.Create('DButton', self.container)
  self.button_no:SetText('')
  self.button_no.perm_value = PERM_NO
  self.button_no.Paint = paint_button
  self.button_no.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('ui/buttonclick.wav')
    self:select_button(btn)
  end

  self.button_no.DoRightClick = request_temporary

  self.button_never = vgui.Create('DButton', self.container)
  self.button_never:SetText('')
  self.button_never.perm_value = PERM_NEVER
  self.button_never.Paint = paint_button
  self.button_never.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('buttons/button10.wav')
    self:select_button(btn)
  end

  self.button_never.DoRightClick = request_temporary

  self.decision = vgui.Create('DLabel', self.container)
  self.decision:SetFont(font)
  self.decision:SetText('')
  self.decision:SetMouseInputEnabled(true)
  self.decision:SetTooltip(t'ui.admin.decided.tooltip')

  self.decision_text = nil

  self:InvalidateLayout()
end

--- Shows what the edited player may do now and which layer decides it, in green when the
-- permission is allowed and in red when it is not. The editor calls it whenever the
-- permissions of the player change; values that were just set show once the server has sent
-- them back.
function PANEL:update_decision()
  if !IsValid(self.decision) then return end

  local target = self:get_player()
  local text, allowed = '', false

  if IsValid(target) then
    local layer

    allowed, layer = Bolt:get_permission_layer(target, self:get_permission().id)
    text = t(allowed ? 'ui.admin.decided.allowed' : 'ui.admin.decided.denied')

    if layer then
      text ..= ' · '..t('ui.admin.decided.'..layer)
    end
  end

  if text == self.decision_text then return end

  self.decision_text = text
  self.decision:SetText(text)
  self.decision:SetTextColor(Theme.get_color(allowed ? 'success' : 'danger'))
end

--- Lays the row out for its current size: the title, a column for each button and the
-- label of the deciding layer, so that the row follows the width of the list it sits in.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  if !IsValid(self.container) then return end

  local title_w, column_w = get_columns(w)
  local padding = math.scale(8)
  local button_y = math.scale(2)
  local button_h = h - button_y * 2

  self.title:SetPos(padding, 0)
  self.title:SetSize(title_w - padding, h)

  for i, button in ipairs({ self.button_allow, self.button_no, self.button_never }) do
    button:SetPos(title_w + column_w * (i - 1), button_y)
    button:SetSize(column_w * 0.9, button_h)
  end

  local decision_x = title_w + column_w * 3

  self.decision:SetPos(decision_x, 0)
  self.decision:SetSize(w - decision_x - padding, h)
end

--- Marks a button as the selected value and, if that differs from the current value of the
-- edited layer (the player's own permission or their character's), sends the change to the
-- server.
-- @param button [Panel one of the row's value buttons]
function PANEL:select_button(button)
  local value = button.perm_value or PERM_NO
  local perm = self:get_permission()

  self.permission_value = value

  button.is_selected = true

  local target = self:get_player()

  if IsValid(target) then
    local current = self.layer == 'character' and target:get_character_permission(perm.id) or
      target:get_permission(perm.id)

    if value != current then
      Cable.send(layer_messages[self.layer].set, target, perm.id, value)
    end
  end

  if IsValid(self.prev_button) and self.prev_button != button then
    self.prev_button.is_selected = false
  end

  self.prev_button = button
end

--- Sets the player whose permission this row edits.
-- @param target [Player]
function PANEL:set_player(target)
  self.active_player = target
end

--- Returns the player whose permission this row edits.
-- @return [Player the player, or nil if none has been set]
function PANEL:get_player()
  return self.active_player
end

--- Sets which layer of the player's permissions this row edits.
-- @param layer [String 'user' for the player's own permissions, 'character' for those of
--   their active character]
function PANEL:set_layer(layer)
  self.layer = layer
end

--- Sets the permission this row stands for and rebuilds the row.
-- @param perm={} [Map permission data as stored by Bolt:add_permission]
function PANEL:set_permission(perm)
  self.permission = perm or {}

  self:rebuild()
end

--- Returns the permission this row stands for.
-- @return [Map permission data]
function PANEL:get_permission()
  return self.permission
end

--- Returns the currently selected permission value.
-- @return [Number PERM_ALLOW, PERM_NO or PERM_NEVER]
function PANEL:get_value()
  return self.permission_value
end

--- Returns the button that stands for a permission value.
-- @param perm [Number PERM_ value; anything but PERM_ALLOW and PERM_NEVER gives the 'not set'
--   button]
-- @return [Panel]
function PANEL:get_button(perm)
  if perm == PERM_ALLOW then
    return self.button_allow
  elseif perm == PERM_NEVER then
    return self.button_never
  else
    return self.button_no
  end
end

--- Selects the button for a permission value, exactly as if it had been clicked.
-- @param perm [Number PERM_ value]
function PANEL:set_value(perm)
  self:select_button(self:get_button(perm))
end

--- Marks the button for a permission value as temporary and shows the remaining time in its
-- tooltip. The previously marked button is cleared.
-- @param perm [Number PERM_ value]
-- @param expires [Number unix timestamp at which it expires, 0 to clear the mark]
function PANEL:set_temporary(perm, expires)
  local button = self:get_button(perm)
  button.is_temp = expires != 0 ? true : nil

  button:SetTooltip(expires != 0 and t'ui.admin.expires'..' '..Flux.Lang:nice_time(expires - os.time()) or false)

  if IsValid(self.prev_temp) and self.prev_temp != button then
    self.prev_temp.is_temp = nil
    self.prev_temp:SetTooltip(false)
  end

  self.prev_temp = button
end

vgui.Register('fl_permission', PANEL, 'fl_base_panel')

--- The permission editor: a switch between the player's own permissions and those of the
-- character they have loaded, and every registered permission, grouped by category, with an
-- `fl_permission` row each and buttons that set a whole category at once.
local PANEL = {}

--- The networked variables of a player that the decisions of the rows depend on.
local watched_vars = {
  role = true,
  permissions = true,
  temp_permissions = true,
  character_permissions = true,
  character_temp_permissions = true
}

--- The networked variables that hold the values of each layer, by layer.
local layer_vars = {
  user = { permissions = true, temp_permissions = true },
  character = { character_permissions = true, character_temp_permissions = true }
}

--- Creates the switch between the layers and the list of permission rows, and makes the
-- editor known to the plugin as `Bolt.permissions_editor`, so that it hears of the changes to
-- the edited player's permissions.
function PANEL:Init()
  self.layer = 'user'

  Bolt.permissions_editor = self

  local font = Theme.get_font('text_smaller')

  self.layer_bar = vgui.Create('fl_base_panel', self)
  self.layer_bar:Dock(TOP)
  self.layer_bar:DockMargin(0, 0, 0, math.scale(6))
  self.layer_bar:SetTall(math.scale(30))
  self.layer_bar.PerformLayout = function(_pnl, w, h)
    local button_w = math.floor(w * 0.5) - math.scale(2)

    self.user_button:SetPos(0, 0)
    self.user_button:SetSize(button_w, h)
    self.character_button:SetPos(w - button_w, 0)
    self.character_button:SetSize(button_w, h)
  end

  for _, layer in ipairs({ 'user', 'character' }) do
    local button = vgui.Create('fl_button', self.layer_bar)
    button:SetFont(font)
    button:SetDrawBackground(true)
    button:set_draw_outline(true)
    button:set_centered(true)
    button.DoClick = function(_btn)
      if self.layer == layer then return end

      surface.PlaySound('buttons/button14.wav')
      self:set_layer(layer)
    end

    self[layer..'_button'] = button
  end

  self.user_button:set_text(t'ui.admin.layer.user')
  self.user_button:SetTooltip(t'ui.admin.layer.user_tooltip')
  self.character_button:SetTooltip(t'ui.admin.layer.character_tooltip')

  self:update_layer_bar()
  self:rebuild()
end

--- Returns the ID of the character the edited player has loaded.
-- @return [Number character ID, nil if no player is edited or the player has no character
--   loaded]
function PANEL:get_character_id()
  local target = self:get_player()

  if !IsValid(target) or !isfunction(target.get_character_id) then return end

  local id = tonumber(target:get_character_id())

  if id and id > 0 then
    return id
  end
end

--- Brings the switch between the layers up to date: marks the edited layer, and names the
-- loaded character on its button, which is disabled while the player has none.
function PANEL:update_layer_bar()
  local target = self:get_player()
  local has_character = self:get_character_id() != nil

  self.shown_character_id = self:get_character_id()

  self.user_button:set_active(self.layer == 'user')
  self.character_button:set_active(self.layer == 'character')
  self.character_button:set_enabled(has_character)
  self.character_button:set_text(has_character and t('ui.admin.layer.character', { name = target:name() }) or
    t'ui.admin.layer.no_character')
end

--- Switches the editor between the player's own permissions and those of their character,
-- and loads the values of that layer into the rows.
-- @param layer [String 'user' or 'character']
function PANEL:set_layer(layer)
  self.layer = layer

  local target = self:get_player()

  if IsValid(target) then
    self:set_player(target)
  else
    self:update_layer_bar()
  end
end

--- Brings the editor up to date when a networked variable of the edited player has changed.
-- When the player loads, switches or drops a character, the character's permissions are
-- loaded again while they are edited, or the editor goes back to the player's own
-- permissions when the player has no character any more. When the values of the edited layer
-- change, they are loaded into the rows, and every change to the player's role or
-- permissions refreshes the deciding layer of the rows.
-- @param entity [Entity the entity whose variable has changed]
-- @param key [String name of the variable]
function PANEL:on_net_var_changed(entity, key)
  local target = self:get_player()

  if !IsValid(target) or entity != target then return end

  if key == 'active_character' or key == 'name' then
    if self:get_character_id() != self.shown_character_id and self.layer == 'character' then
      self:set_player(target)
    else
      self:update_layer_bar()
    end
  elseif watched_vars[key] then
    if layer_vars[self.layer][key] then
      self:load_values()
    end

    self:update_decisions()
  end
end

--- Refreshes the deciding layer of the rows once a temporary permission of the edited player
-- has expired.
function PANEL:Think()
  self.BaseClass.Think(self)

  if self.next_expiry and os.time() >= self.next_expiry then
    self:load_values()
    self:update_decisions()
  end
end

--- Refreshes the deciding layer of every row, and notes when the next temporary permission of
-- the edited player expires.
function PANEL:update_decisions()
  local target = self:get_player()
  local now = os.time()
  local next_expiry

  if IsValid(target) then
    for _, perm_table in ipairs({ target:get_temp_permissions(), target:get_character_temp_permissions() }) do
      for _, entry in pairs(perm_table) do
        local expires = tonumber(entry.expires) or 0

        if expires > now and (!next_expiry or expires < next_expiry) then
          next_expiry = expires
        end
      end
    end
  end

  self.next_expiry = next_expiry

  for _, row in pairs(self.permissions) do
    row:update_decision()
  end
end

--- Loads the current values of the edited layer into the rows: the player's own permissions,
-- or those of their character.
function PANEL:load_values()
  local target = self:get_player()

  if !IsValid(target) then return end

  if self.layer == 'character' then
    self:set_permissions(target:get_character_permissions(), target:get_character_temp_permissions())
  else
    self:set_permissions(target:get_permissions(), target:get_temp_permissions())
  end
end

--- Lets the active theme draw the editor through its PaintPermissionEditor hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.call('PaintPermissionEditor', self, w, h)
end

--- Collects the value of every row that is not set to PERM_NO.
-- @return [Map PERM_ values keyed by each row's permission data table]
function PANEL:get_permissions()
  local perm_list = {}

  for _, perm_panel in pairs(self.permissions) do
    local value = perm_panel:get_value()

    if value != PERM_NO then
      perm_list[perm_panel:get_permission()] = value
    end
  end

  return perm_list
end

--- Selects the given values in the matching rows and marks unexpired temporary permissions.
-- Rows that the lists leave out are set to not set, without a temporary mark.
-- @param perm_list [Map PERM_ values keyed by permission ID]
-- @param temp_perm_list=nil [Map tables with value and expires (unix timestamp) fields,
--   keyed by permission ID]
function PANEL:set_permissions(perm_list, temp_perm_list)
  for perm_id, row in pairs(self.permissions) do
    if perm_list[perm_id] == nil then
      row:set_value(PERM_NO)
    end

    row:set_temporary(PERM_NO, 0)
  end

  for perm_id, value in pairs(perm_list) do
    if self.permissions[perm_id] then
      self.permissions[perm_id]:set_value(tonumber(value))
    end
  end

  if temp_perm_list then
    local now = os.time()

    for perm_id, entry in pairs(temp_perm_list) do
      if self.permissions[perm_id] and entry.expires > now then
        self.permissions[perm_id]:set_temporary(tonumber(entry.value), entry.expires)
      end
    end
  end
end

--- Sets the player being edited, rebuilds the rows and loads the values of the edited layer
-- into them: the player's own permissions, or those of their character. The editor goes back
-- to the player's own permissions if the player has no character loaded.
-- @param target [Player]
function PANEL:set_player(target)
  self.active_player = target

  if self.layer == 'character' and !self:get_character_id() then
    self.layer = 'user'
  end

  self:update_layer_bar()
  self:rebuild()
  self:load_values()
  self:update_decisions()
end

--- Returns the player being edited.
-- @return [Player the player, or nil if none has been set]
function PANEL:get_player()
  return self.active_player
end

--- Recreates the list: a collapsible category per permission category with a row for each
-- permission, plus bulk allow / not set / never buttons where a category has several. The
-- list is docked into a scroll panel, so the rows keep clear of the scroll bar.
function PANEL:rebuild()
  if IsValid(self.scroll_panel) then
    self.scroll_panel:safe_remove()
  end

  local permissions = Bolt:get_permissions()

  self.permissions = {}
  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:Dock(FILL)

  self.list_layout = vgui.Create('DListLayout', self.scroll_panel)
  self.list_layout:Dock(TOP)

  local row_height = math.scale(30)

  for category, perms in SortedPairs(permissions) do
    local collapsible_category = vgui.Create('DCollapsibleCategory', self.list_layout)
    collapsible_category:SetLabel(t(category))
    collapsible_category:DockMargin(0, 0, 0, math.scale(6))
    collapsible_category:DockPadding(math.scale(4), math.scale(4), math.scale(4), math.scale(4))

    local category_list = vgui.Create('DListLayout', self.list_layout)

    collapsible_category:SetContents(category_list)

    if table.Count(perms) > 1 then
      local panel = vgui.Create('fl_base_panel')
      panel:SetTall(row_height + math.scale(4))

      local category_buttons = {
        t'ui.admin.allow_all',
        t'ui.admin.no_all',
        t'ui.admin.never_all'
      }

      local buttons = {}

      panel.PerformLayout = function(_pnl, w, h)
        local title_w, column_w = get_columns(w)

        for i, button in ipairs(buttons) do
          button:SetSize(column_w * 0.9, h - math.scale(4))
          button:SetPos(title_w + column_w * (i - 1), math.scale(2))
        end
      end

      for i, label in ipairs(category_buttons) do
        local button = vgui.Create('fl_button', panel)
        buttons[i] = button
        button:SetFont(Theme.get_font('text_smaller'))
        button:SetDrawBackground(true)
        button:set_draw_outline(true)
        button:set_background_color(Theme.get_color('surface_raised'))
        button:set_text(label)
        button:set_centered(true)
        button.DoClick = function(_btn)
          local can_click = false

          for _, perm in pairs(perms) do
            if self.permissions[perm.id]:get_value() != i - 1 then
              can_click = true

              break
            end
          end

          if !can_click then return end

          surface.PlaySound('buttons/button4.wav')

          for _, perm in pairs(perms) do
            self.permissions[perm.id]:set_value(i - 1)
          end
        end
      end

      category_list:Add(panel)
    end

    for _, perm in SortedPairs(perms) do
      local button = vgui.Create('fl_permission', self)
      button:SetTall(row_height)
      button:set_layer(self.layer)
      button:set_permission(perm)
      button:set_value(PERM_NO)
      button:set_player(self:get_player())

      category_list:Add(button)

      self.permissions[perm.id] = button
    end
  end
end

vgui.Register('fl_permissions_editor', PANEL, 'fl_base_panel')
