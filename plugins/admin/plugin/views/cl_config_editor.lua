--- Config editor page of the admin panel, which lets players with the `manage_configuration`
-- permission change config values in game.
-- Changes are requests to the server, which applies them with `Config.change` and
-- `Config.reset`; a line shows a new value once the server has sent it back. The flags of a
-- config decide how its line behaves: a static config is shown but cannot be edited, the
-- value of a private config stays masked until it is revealed, and a config that needs a
-- restart shows the value it will have after the restart, next to a marker that tells
-- which value is in effect until then.

--- The config editor page: a scrollable list of collapsible config categories, each filled
-- with `fl_config_line` rows. Hidden configs are left out, since their values never reach
-- the client.
local PANEL = {}

--- Builds a collapsible category for every config menu category and fills it with config
-- lines, then asks the server to send the config again, so that the private and pending
-- values match what the player may see by now.
function PANEL:Init()
  local width = self:GetWide()
  local categories = {}

  self.lines = {}

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.list_layout = vgui.Create('DListLayout', self.scroll_panel)

  for id, menu_entry in pairs(Config.get_menu_keys()) do
    local category = menu_entry.category or { name = id, description = '' }
    local configs = {}

    for key, config_table in pairs(menu_entry.configs or {}) do
      local definition = Config.get_definition(key)

      if !definition or !definition.hidden then
        table.insert(configs, { key = key, config = config_table, name = t(config_table.name) })
      end
    end

    if #configs > 0 then
      table.sort(configs, function(first, second)
        return first.name < second.name
      end)

      table.insert(categories, {
        name = t(category.name or id),
        description = category.description,
        configs = configs
      })
    end
  end

  table.sort(categories, function(first, second)
    return first.name < second.name
  end)

  for k, v in ipairs(categories) do
    local collapsible_category = vgui.Create('DCollapsibleCategory', self.list_layout)
    collapsible_category:SetLabel(v.name)
    collapsible_category:SetSize(width, 21)
    collapsible_category:DockMargin(0, 0, 0, math.scale(6))
    collapsible_category:DockPadding(math.scale(4), math.scale(4), math.scale(4), math.scale(4))

    if isstring(v.description) and v.description != '' then
      collapsible_category.Header:SetTooltip(t(v.description))
    end

    local config_list = vgui.Create('DListLayout', self.list_layout)

    collapsible_category:SetContents(config_list)

    for k1, v1 in ipairs(v.configs) do
      local config_line = vgui.Create('fl_config_line')
      config_line:set_config(v1.key, v1.config)
      config_line:SetWide(width)
      config_line.dark = k1 % 2 == 0

      config_list:Add(config_line)

      self.lines[v1.key] = config_line
    end
  end

  Bolt.config_editor = self

  Config.request()
end

--- Sizes the scroll panel and the list once the admin panel has opened this page.
function PANEL:on_opened()
  local width, height = self:GetWide(), self:GetTall()

  self.scroll_panel:SetSize(width, height)
  self.list_layout:SetSize(width - 16, height)
end

--- Brings the line of a config up to date after its value or its pending value has arrived
-- from the server.
-- @param key [String config key]
function PANEL:update_config(key)
  local config_line = self.lines[key]

  if IsValid(config_line) then
    config_line:update()
  end
end

vgui.Register('fl_config_editor', PANEL, 'fl_base_panel')

--- A row of the config editor: the name of a config value, markers for its flags, the
-- control that matches its type (slider, checkbox, text entry, list editor or dropdown) and
-- a button that resets it to its default. Changes are sent to the server.
local PANEL = {}
PANEL.dark = false

--- Creates the label that shows the config's name and the button that resets the config.
function PANEL:Init()
  self.flags = {}
  self.text_width = 0

  self.text = vgui.Create('DLabel', self)
  self.text:SetFont(Theme.get_font('text_small'))
  self.text:SetTextColor(Theme.get_color('text'))

  self.reset_button = vgui.Create('fl_button', self)
  self.reset_button:SetDrawBackground(false)
  self.reset_button:SetTooltip(t'ui.admin.config.reset')
  self.reset_button:set_icon('fa-undo')
  self.reset_button:set_centered(true)
  self.reset_button.DoClick = function(btn)
    if self.key then
      Cable.send('fl_config_reset', self.key)
    end
  end
end

--- Lets the active theme draw the line through its PaintConfigLine hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintConfigLine', self, w, h)
end

--- Sends the value of the slider to the server half a second after it was last moved, once
-- the player has let go of it.
function PANEL:Think()
  self.BaseClass.Think(self)

  local slider = self.slider

  if self.send_at and self.send_at <= CurTime() and IsValid(slider) and !slider:IsEditing() then
    local value = math.round(slider:GetValue(), self.config.data.decimals or 0)

    self.send_at = nil

    if value != self:get_value() then
      Cable.send('fl_config_change', self.key, value)
    end
  end
end

--- Positions the name, the flag markers after it, the reset button on the right and the
-- control in the right half of the line.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(4)
  local button_size = h - padding * 2
  local flags_width = #self.flags * (button_size + padding)
  local control_x = math.floor(w * 0.5)

  self.text:SetSize(math.max(math.min(self.text_width, control_x - flags_width - padding * 3), 0), h)
  self.text:SetPos(padding, 0)

  local flags_x = padding * 2 + self.text:GetWide()
  local icon_size = math.floor(button_size * 0.75)

  for k, v in ipairs(self.flags) do
    v:SetSize(button_size, button_size)
    v:SetPos(flags_x + (k - 1) * (button_size + padding), padding)
    v:set_icon_size(icon_size)
  end

  self.reset_button:SetSize(button_size, button_size)
  self.reset_button:SetPos(w - button_size - padding, padding)
  self.reset_button:set_icon_size(icon_size)

  if IsValid(self.control) then
    local control_width = w - control_x - button_size - padding * 3

    if self.control == self.check then
      self.control:SetSize(button_size, button_size)
      self.control:SetPos(control_x + control_width * 0.5 - button_size * 0.5, padding)
      self.control:set_icon_size(button_size)
    else
      self.control:SetPos(control_x, 2)
      self.control:SetSize(control_width, h - 4)
    end
  end
end

--- Returns the value the line shows: the pending value of a config that waits for a restart,
-- the current value otherwise.
-- @return [Any]
function PANEL:get_value()
  local has_pending, pending_value = Config.get_pending(self.key)

  if has_pending then
    return pending_value
  end

  return Config.get(self.key)
end

--- Adds a small icon after the name of the config that marks one of its flags.
-- @param icon [String FontAwesome icon ID]
-- @param tooltip [String text shown when the icon is hovered]
-- @param on_click=nil [Function called without arguments when the icon is clicked]
-- @return [Panel the created fl_button]
function PANEL:add_flag(icon, tooltip, on_click)
  local flag = vgui.Create('fl_button', self)
  flag:SetDrawBackground(false)
  flag:SetTooltip(tooltip)
  flag:set_icon(icon)
  flag:set_centered(true)

  if on_click then
    flag.DoClick = function(btn)
      on_click()
    end
  end

  table.insert(self.flags, flag)

  return flag
end

--- Binds the line to a config entry: shows its name, marks its flags (a lock for a static
-- config, a clock for one that needs a restart, an eye that reveals the value of a private
-- one) and creates the control for its data type.
-- @param key [String config key]
-- @param config_table [Map the config's menu entry (name, description, type, data)]
function PANEL:set_config(key, config_table)
  local static_text, reveal_text = t'ui.admin.config.static', t'ui.admin.config.reveal'

  self.key = key
  self.config = config_table
  self.config.data = self.config.data or {}
  self.revealed = !Config.is_private(key)

  self:SetTooltip(t(config_table.description))

  self.text:SetText(t(config_table.name))
  self.text:SizeToContents()
  self.text_width = self.text:GetWide()

  self:SetTall(math.scale(36))

  if Config.is_static(key) then
    self:add_flag('fa-lock', static_text)
  else
    if Config.needs_restart(key) then
      self.restart_flag = self:add_flag('fa-history', '')
    end

    if Config.is_private(key) then
      self.private_flag = self:add_flag('fa-eye-slash', reveal_text, function()
        self.revealed = !self.revealed
        self.private_flag:set_icon(self.revealed and 'fa-eye' or 'fa-eye-slash')

        self:create_control()
      end)
    end
  end

  self.reset_button:set_enabled(!Config.is_static(key) and Config.get_default(key) != nil)

  self:create_control()
end

--- Creates the control of the line anew and fills it with the value of the config. A static
-- config and a private one that has not been revealed get a text that cannot be edited;
-- any other config gets the control of its data type: a slider, a checkbox, a text entry,
-- a list editor or a dropdown.
function PANEL:create_control()
  local key, config_table = self.key, self.config
  local data = config_table.data
  local data_type = config_table.type == 'bool' and 'boolean' or config_table.type
  local small_font = Theme.get_font('text_small')

  if IsValid(self.control) then
    self.control:safe_remove()
  end

  self.control = nil
  self.update_control = nil
  self.slider = nil
  self.check = nil
  self.send_at = nil

  if Config.is_static(key) or !self.revealed then
    local label = vgui.Create('DLabel', self)
    label:SetFont(small_font)
    label:SetTextColor(Theme.get_color('text'))
    label:SetContentAlignment(5)

    self.control = label
    self.update_control = function(value)
      label:SetText(Config.get(key) != nil and Config.display_value(key) or '')
    end
  elseif data_type == 'number' then
    local slider = vgui.Create('DNumSlider', self)
    slider:SetMin(data.min_value or 0)
    slider:SetMax(data.max_value or 100)
    slider:SetDecimals(data.decimals or 0)
    slider.Label:SetVisible(false)
    slider.TextArea:SetPaintBackground(true)
    slider.PerformLayout = function(pnl)
      pnl.Label:SetWide(0)
    end

    slider.OnValueChanged = function(pnl, value)
      if !self.updating then
        self.send_at = CurTime() + 0.5
      end
    end

    self.control = slider
    self.slider = slider
    self.update_control = function(value)
      if slider:IsEditing() or self.send_at then return end

      value = tonumber(value) or tonumber(data.default_value) or 0

      slider:SetValue(value)
      slider:ValueChanged(value)
    end
  elseif data_type == 'boolean' then
    local check = vgui.Create('fl_button', self)
    check:SetDrawBackground(false)
    check:set_centered(true)
    check.DoClick = function(btn)
      Cable.send('fl_config_change', key, !btn.value)
    end

    self.control = check
    self.check = check
    self.update_control = function(value)
      check.value = value == true
      check:set_icon(check.value and 'fa-toggle-on' or 'fa-toggle-off')
      check:set_text_color(check.value and Theme.get_color('success') or Theme.get_color('text_dim'))
    end
  elseif data_type == 'string' then
    local text_entry = vgui.Create('DTextEntry', self)
    text_entry:SetFont(small_font)
    text_entry.OnEnter = function(pnl)
      Cable.send('fl_config_change', key, pnl:GetValue())
    end

    self.control = text_entry
    self.update_control = function(value)
      if !text_entry:IsEditing() then
        text_entry:SetValue(value != nil and tostring(value) or '')
      end
    end
  elseif data_type == 'table' then
    local combo_box = vgui.Create('DComboBox', self)
    local new_title, new_text = t'ui.admin.new_config', t'ui.admin.new_config_text'
    local delete_title, delete_text = t'ui.admin.delete_config', t'ui.admin.delete_config_text'
    local yes, no = t'ui.yes', t'ui.no'
    local values = {}

    combo_box:SetSortItems(false)
    combo_box.OnSelect = function(pnl, index, text, position)
      local new_values = table.Copy(values)

      if position == 0 then
        Derma_StringRequest(new_title, new_text, '', function(entered)
          if entered != '' then
            table.insert(new_values, entered)

            Cable.send('fl_config_change', key, new_values)
          end
        end)
      else
        Derma_Query(delete_text, delete_title, yes, function()
          table.remove(new_values, position)

          Cable.send('fl_config_change', key, new_values)
        end, no)
      end

      self:update()
    end

    self.control = combo_box
    self.update_control = function(value)
      local names = {}

      values = istable(value) and value or {}

      combo_box:Clear()

      for k, v in ipairs(values) do
        names[k] = tostring(v)

        combo_box:AddChoice(names[k], k)
      end

      combo_box:AddChoice(new_title, 0)
      combo_box:SetValue(#names > 0 and table.concat(names, ', ') or new_title)
    end
  elseif data_type == 'dropdown' then
    local combo_box = vgui.Create('DComboBox', self)
    local select_text = t'ui.admin.config.select'
    local choices = istable(data.choices) and data.choices or data

    combo_box:SetSortItems(false)

    for k, v in ipairs(choices) do
      if isstring(v) or isnumber(v) then
        combo_box:AddChoice(t(tostring(v)), v)
      end
    end

    combo_box.OnSelect = function(pnl, index, text, value)
      Cable.send('fl_config_change', key, value)
    end

    self.control = combo_box
    self.update_control = function(value)
      combo_box:SetValue(value != nil and t(tostring(value)) or select_text)
    end
  end

  self:update()
  self:InvalidateLayout()
end

--- Brings the line up to date with the config: shows its value in the control, unless the
-- player is in the middle of editing it, and refreshes the marker of a config that needs
-- a restart, which is highlighted while a value is waiting for the restart.
function PANEL:update()
  if !self.key then return end

  if self.update_control and IsValid(self.control) then
    self.updating = true
    self.update_control(self:get_value())
    self.updating = false
  end

  if IsValid(self.restart_flag) then
    local tooltip = t'ui.admin.config.needs_restart'
    local has_pending = Config.get_pending(self.key)

    if has_pending then
      tooltip = tooltip..' '..t('ui.admin.config.pending', { value = Config.display_value(self.key) })
    end

    self.restart_flag:SetTooltip(tooltip)
    self.restart_flag:set_text_color(has_pending and Theme.get_color('warning') or nil)
  end
end

vgui.Register('fl_config_line', PANEL, 'fl_base_panel')
