local PANEL = {}

--- Builds a collapsible category for every config menu category and fills it with config
-- lines.
function PANEL:Init()
  local width, height = self:GetWide(), self:GetTall()

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.list_layout = vgui.Create('DListLayout', self.scroll_panel)

  for k, v in pairs(Config.get_menu_keys()) do
    local collapsible_category = vgui.Create('DCollapsibleCategory', self.list_layout)
    collapsible_category:SetLabel(t(v.category.name))
    collapsible_category:SetSize(width, 21)

    collapsible_category.Header:SetTooltip(t(v.category.description))

    local list = vgui.Create('DListLayout', self.list_layout)

    collapsible_category:SetContents(list)

    local dark = false

    for k1, v1 in pairs(v.configs) do
      local config_line = vgui.Create('fl_config_line')
      config_line:set_config(k1, v1)
      config_line:SetWide(width)
      config_line.dark = dark

      list:Add(config_line)

      dark = !dark
    end
  end
end

--- Sizes the scroll panel and the list once the admin panel has opened this page.
function PANEL:on_opened()
  local width, height = self:GetWide(), self:GetTall()

  self.scroll_panel:SetSize(width, height)
  self.list_layout:SetSize(width - 16, height)
end

vgui.Register('fl_config_editor', PANEL, 'fl_base_panel')

local PANEL = {}

--- Creates the label that shows the config's name.
function PANEL:Init()
  self.text = vgui.Create('DLabel', self)
  self.text:SetFont(Theme.get_font('main_menu_normal'))
  self.text:SetTextColor(color_white)
  self.text:SetContentAlignment(5)
end

--- Lets the active theme draw the line through its PaintConfigLine hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintConfigLine', self, w, h)
end

--- Positions the label and the control that matches the config's data type.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local config_table = self.config

  self.text:SetPos(2, h / 2 - self.text:GetTall() / 2)
  self.text:SizeToContents()

  local data_type = config_table.type

  if data_type == 'number' then
    self.slider:SetPos(w / 2, 2)
    self.slider:SetSize(w / 2 - 2, h - 4)
  elseif data_type == 'boolean' then
    local size = h * 0.8
    self.check:SetSize(size, size)
    self.check:SetPos(w * 0.75 - size / 2, h / 2 - size / 2)
    self.check:set_icon_size(size)
  elseif data_type == 'string' then
    self.text_entry:SetPos(w / 2, 2)
    self.text_entry:SetSize(w / 2 - 2, h - 4)
  elseif data_type == 'table' then
    self.combo_box:SetPos(w / 2, 2)
    self.combo_box:SetSize(w / 2 - 2, h - 4)
  end
end

--- Binds the line to a config entry and creates the control for its data type: slider,
-- checkbox, text entry, list editor or dropdown. Changes are sent to the server.
-- @param key [String config key]
-- @param config_table [Map the config's menu entry (name, description, type, data)]
function PANEL:set_config(key, config_table)
  self.config = config_table

  self:SetTooltip(t(config_table.description))

  self.text:SetText(t(config_table.name))
  self.text:SizeToContents()

  self:SetTall(self.text:GetTall() * 1.5)

  local data_type = config_table.type

  if data_type == 'number' then
    self.slider = vgui.Create('DNumSlider', self)
    self.slider:SetMin(config_table.data.min_value or 0)
    self.slider:SetMax(config_table.data.max_value or 100)
    self.slider:SetDecimals(config_table.data.decimals or 0)
    self.slider:SetValue(Config.get(key) or config_table.data.default_value or 0)
    self.slider.TextArea:SetPaintBackground(true)
    self.slider.PerformLayout = function()
    end

    local timer_id = 'fl_config_set_'..key

    timer.Create(timer_id, 0.5, 0, function()
      if IsValid(self) and IsValid(self.slider) and !self.slider:IsEditing() then
        local value = math.round(self.slider:GetValue(), config_table.decimals)

        if value != Config.get(key) then
          Cable.send('fl_config_change', key, value)
          timer.Pause(timer_id)
        end
      end
    end)

    timer.Pause(timer_id)

    self.slider.OnValueChanged = function(pnl, value)
      timer.UnPause(timer_id)
    end
  elseif data_type == 'boolean' then
    self.check = vgui.Create('fl_button', self)
    self.check.value = Config.get(key) or config_table.data.default_value or false
    self.check:SetDrawBackground(false)
    self.check:set_icon(self.check.value and 'fa-check' or 'fa-ban')
    self.check:set_centered(true)
    self.check.DoClick = function(btn)
      btn.value = !btn.value

      Cable.send('fl_config_change', key, btn.value)

      self.check:set_icon(btn.value and 'fa-check' or 'fa-ban')
    end
  elseif data_type == 'string' then
    self.text_entry = vgui.Create('DTextEntry', self)
    self.text_entry:SetValue(Config.get(key) or config_table.data.default_value or '')
    self.text_entry:SetFont(Theme.get_font('main_menu_small'))
    self.text_entry.OnEnter = function(pnl, value)
      Cable.send('fl_config_change', key, self.text_entry:GetValue())
    end
  elseif data_type == 'table' then
    self.combo_box = vgui.Create('DComboBox', self)

    local data_table = Config.get(key)

    self.combo_box.rebuild = function()
      self.combo_box:Clear()
      self.combo_box:SetValue(t(config_table.name))

      if istable(data_table) then
        for k, v in pairs(data_table) do
          self.combo_box:AddChoice(t(v), v)
        end
      end

      self.combo_box:AddChoice(t'ui.admin.new_config', '')
    end

    self.combo_box:rebuild()

    self.combo_box.OnSelect = function(pnl, index, text, data)

      if data == '' then
        Derma_StringRequest(t'ui.admin.new_config',
        t'ui.admin.new_config_text',
        '', function(text)
          if text != '' then
            table.insert(data_table, text)

            Cable.send('fl_config_change', key, data_table)

            self.combo_box.rebuild()
          end
        end)
      else
        Derma_Query(t'ui.admin.delete_config_text',
        t'ui.admin.delete_config',
        t'ui.yes', function()
          table.remove(data_table, index)

          Cable.send('fl_config_change', key, data_table)

          self.combo_box.rebuild()
        end, t'ui.no')
      end
    end
  elseif data_type == 'dropdown' then
    self.combo_box = vgui.Create('DComboBox', self)
    self.combo_box:SetValue(Config.get(key) or t'ui.admin.select_config')

    local data_table = config_table.data

    if data_table then
      for k, v in pairs(data_table) do
        self.combo_box:AddChoice(t(v), v)
      end
    end

    self.combo_box.OnSelect = function(pnl, index, text, data)
      Cable.send('fl_config_change', key, data)
    end
  end
end

vgui.Register('fl_config_line', PANEL, 'fl_base_panel')
