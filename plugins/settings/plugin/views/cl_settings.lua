--- The settings menu of the tab menu: `fl_settings`, the list of the settings the player can
-- change, grouped by category, and `fl_setting_row`, the line of a single setting.
-- Themes can draw both themselves with the `PaintSettingsMenu` and `PaintSettingRow` theme
-- hooks.

local background_color = Color(50, 50, 50, 100)

--- The settings page of the tab menu (`fl_settings`): a scrollable list with a header for
-- every category and an `fl_setting_row` for every setting that is visible to the player,
-- and a button that sets all of them back to their defaults.
-- `rebuild` recreates the list; the plugin calls `update_setting` when a value changes.
-- Derives from `fl_base_panel`.
local PANEL = {}

--- Creates the scroll panel that holds the list and the button that resets the listed
-- settings after a confirmation, and makes the panel known to the plugin.
function PANEL:Init()
  self.rows = {}
  self.listed = ''

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.reset_button = vgui.Create('fl_button', self)
  self.reset_button:SetDrawBackground(true)
  self.reset_button:SetFont(Theme.get_font('text_small'))
  self.reset_button:set_text(t'ui.settings.reset_all')
  self.reset_button:set_icon('fa-undo')
  self.reset_button:set_icon_size(math.scale(16))
  self.reset_button:set_text_offset(math.scale(8))
  self.reset_button:set_centered(true)
  self.reset_button:set_background_color(Theme.get_color('background_light'))
  self.reset_button:SetTall(math.scale(32))
  self.reset_button:SizeToContentsX()
  self.reset_button.DoClick = function(btn)
    local ids = table.GetKeys(self.rows)
    local message, title = t'ui.settings.reset_all_message', t'ui.settings.reset_all'
    local yes, no = t'ui.yes', t'ui.no'

    Derma_Query(message, title, yes, function()
      for k, v in ipairs(ids) do
        ClientSettings:reset(v)
      end
    end, no)
  end

  ClientSettings.menu = self
end

--- Draws the background and the title of the menu, unless the active theme does that in its
-- PaintSettingsMenu hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintSettingsMenu', self, w, h) == nil then
    local text = t'ui.settings.title'
    local font = Theme.get_font('main_menu_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.RoundedBox(0, -4, -4, w + 8, h + 8, background_color)
      draw.textured_rect(
        Theme.get_material('gradient_down'),
        -4,
        -text_h - 4,
        text_w + 8,
        text_h,
        background_color
      )
      draw.SimpleText(text, font, 0, -text_h - 4, color_white)
    DisableClipping(false)
  end
end

--- Rebuilds the list on the frame after the set of visible settings has changed.
function PANEL:Think()
  self.BaseClass.Think(self)

  if self.should_rebuild then
    self:rebuild()
  end
end

--- Keeps the list above the reset button, which stays in the bottom right corner.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local button_w, button_h = self.reset_button:GetSize()

  self.scroll_panel:SetPos(padding, padding)
  self.scroll_panel:SetSize(w - padding * 2, h - button_h - padding * 3)

  self.reset_button:SetPos(w - button_w - padding, h - button_h - padding)
end

--- Returns the IDs of the listed settings as one string, which changes whenever a setting
-- appears in the list, disappears from it or moves.
-- @param categories [List<Map> categories returned by ClientSettings:get_categories]
-- @return [String]
function PANEL:get_listed(categories)
  local ids = {}

  for k, v in ipairs(categories) do
    for k1, v1 in ipairs(v.settings) do
      table.insert(ids, v1.id)
    end
  end

  return table.concat(ids, ';')
end

--- Recreates the list: a header for every category followed by the rows of its settings,
-- or a notice if there is no setting to show.
function PANEL:rebuild()
  local categories = ClientSettings:get_categories()
  local text_color = Theme.get_color('text')
  local margin = math.scale(4)
  local row_height = math.scale(36)

  self.should_rebuild = false
  self.rows = {}
  self.listed = self:get_listed(categories)

  self.scroll_panel:Clear()

  if #categories == 0 then
    local notice = self.scroll_panel:Add('DLabel')
    notice:SetText(t'ui.settings.empty')
    notice:SetFont(Theme.get_font('text_small'))
    notice:SetTextColor(text_color)
    notice:SetContentAlignment(5)
    notice:SizeToContents()
    notice:Dock(TOP)
    notice:DockMargin(0, margin * 4, 0, 0)
  end

  for k, v in ipairs(categories) do
    local header = self.scroll_panel:Add('DLabel')
    header:SetText(v.name)
    header:SetFont(Theme.get_font('text_normal'))
    header:SetTextColor(text_color)
    header:SizeToContents()
    header:Dock(TOP)
    header:DockMargin(margin, k == 1 and 0 or margin * 4, 0, margin)

    for k1, v1 in ipairs(v.settings) do
      local row = self.scroll_panel:Add('fl_setting_row')
      row:SetTall(row_height)
      row:Dock(TOP)
      row:set_dark(k1 % 2 == 1)
      row:set_setting(v1)

      self.rows[v1.id] = row
    end
  end

  self.reset_button:set_enabled(#categories > 0)
end

--- Updates the menu after the value of a setting has changed: the row of the setting, or
-- the whole list on the next frame if the change has made settings appear or disappear.
-- @param id [String setting id]
function PANEL:update_setting(id)
  if self:get_listed(ClientSettings:get_categories()) != self.listed then
    self.should_rebuild = true

    return
  end

  local row = self.rows[id]

  if IsValid(row) then
    row:update()
  end
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(960), math.scale(800)
end

vgui.Register('fl_settings', PANEL, 'fl_base_panel')

--- The line of one setting in the settings menu (`fl_setting_row`): the name of the setting,
-- the control its type creates for it and a button that sets it back to its default.
-- Assign the setting with `set_setting`. The description of the setting is the tooltip of
-- the row. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.dark = false

--- Creates the label of the setting and the button that resets it.
function PANEL:Init()
  self.label = vgui.Create('DLabel', self)
  self.label:SetFont(Theme.get_font('text_small'))
  self.label:SetTextColor(Theme.get_color('text'))

  self.reset_button = vgui.Create('fl_button', self)
  self.reset_button:SetDrawBackground(false)
  self.reset_button:SetSize(math.scale(24), math.scale(24))
  self.reset_button:SetTooltip(t'ui.settings.reset')
  self.reset_button:set_icon('fa-undo')
  self.reset_button:set_icon_size(math.scale(16))
  self.reset_button:set_centered(true)
  self.reset_button.DoClick = function(btn)
    if self.setting then
      ClientSettings:reset(self.setting.id)
    end
  end
end

--- Draws a darker background on the rows that are marked as dark, unless the active theme
-- draws the row in its PaintSettingRow hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintSettingRow', self, w, h) == nil and self.dark then
    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
  end
end

--- Puts the label on the left, the reset button on the right and the control of the setting
-- between the middle of the row and the reset button.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local button_w, button_h = self.reset_button:GetSize()
  local control_x = math.floor(w * 0.5)

  self.label:SetSize(math.min(self.label_width or 0, control_x - padding * 2), h)
  self.label:SetPos(padding, 0)

  self.reset_button:SetPos(w - button_w - padding, math.floor(h * 0.5 - button_h * 0.5))

  if IsValid(self.control) then
    local margin = math.scale(4)

    self.control:SetPos(control_x, margin)
    self.control:SetSize(w - control_x - button_w - padding * 2, h - margin * 2)
  end
end

--- Sets whether the row is drawn with a darker background, which the menu does for every
-- other row.
-- @param dark [Boolean]
function PANEL:set_dark(dark)
  self.dark = dark
end

--- Sets the setting this row edits and creates the control for it.
-- @param setting [Map setting definition]
function PANEL:set_setting(setting)
  self.setting = setting

  self.label:SetText(t(setting.name))
  self.label:SizeToContents()
  self.label_width = self.label:GetWide()

  if setting.description then
    self:SetTooltip(t(setting.description))
  end

  self:create_control()
end

--- Returns the setting this row edits.
-- @return [Map setting definition, or nil if it has not been set yet]
function PANEL:get_setting()
  return self.setting
end

--- Creates the control of the setting anew through the type of the setting, showing the
-- current value, and updates the reset button.
function PANEL:create_control()
  local setting = self.setting
  local type_data = ClientSettings:find_type(setting.type)

  if IsValid(self.control) then
    self.control:safe_remove()
  end

  self.control = nil
  self.shown_value = ClientSettings:get(setting.id)

  if type_data and type_data.create_control then
    self.control = type_data.create_control(setting, self, self.shown_value, function(value)
      value = ClientSettings:sanitize(setting.id, value)

      if value == nil then return end

      self.shown_value = value

      ClientSettings:set(setting.id, value)
    end)
  end

  self.reset_button:set_enabled(!ClientSettings:is_default(setting.id))

  self:InvalidateLayout()
end

--- Brings the row up to date with the value of its setting: recreates the control if the
-- value was not changed through it, and enables the reset button unless the setting is at
-- its default.
function PANEL:update()
  if !self.setting then return end

  if ClientSettings:get(self.setting.id) != self.shown_value then
    self:create_control()
  else
    self.reset_button:set_enabled(!ClientSettings:is_default(self.setting.id))
  end
end

vgui.Register('fl_setting_row', PANEL, 'fl_base_panel')
