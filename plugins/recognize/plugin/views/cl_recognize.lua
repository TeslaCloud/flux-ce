--- The recognize menu (`fl_recognize`), which the Recognize plugin opens on the ShowTeam key:
-- the player picks who hears the introduction (the player they look at, or everyone within
-- whisper, talk or yell range) and introduces themselves under their real name or a false
-- one. The false names used before are kept on the client and offered again.

local scale = math.scale

local PANEL = {}

--- Builds the recognize menu with range buttons, a real name button, a fake name entry and the name history.
function PANEL:Init()
  local scr_w, scr_h = ScrW(), ScrH()
  local margin = scale(4)
  local total_height = 0

  self:SetWide(scr_w * 0.25)
  self:SetTitle(t'ui.recognize.title')
  self:set_draggable(true)

  self.list = vgui.Create('DScrollPanel', self)
  self.list:Dock(FILL)

  self.label = vgui.Create('DLabel', self.list)
  self.label:Dock(TOP)
  self.label:SetText(t'ui.recognize.message')
  self.label:SetFont(Theme.get_font('text_normal_smaller'))
  self.label:SetTextColor(Theme.get_color('schema_text'))
  self.label:SetMultiline(true)
  self.label:SetWrap(true)
  self.label:SetAutoStretchVertical(true)

  total_height = total_height + self.label:GetTall()

  local icon_size = scale(32)
  local range_buttons = {
    target = {
      name = t'ui.recognize.types.target',
      icon = 'fa-crosshairs'
    },
    talk = {
      name = t'ui.recognize.types.talk',
      icon = 'fa-volume-down'
    },
    whisper = {
      name = t'ui.recognize.types.whisper',
      icon = 'fa-volume-off'
    },
    yell = {
      name = t'ui.recognize.types.yell',
      icon = 'fa-volume-up'
    }
  }

  self.range_buttons = vgui.Create('fl_base_panel', self.list)
  self.range_buttons:SetSize((icon_size + margin) * #range_buttons, icon_size)
  self.range_buttons:DockMargin(0, margin, 0, 0)
  self.range_buttons:Dock(TOP)

  total_height = total_height + icon_size + margin

  self.ranges = {}

  for k, v in pairs(range_buttons) do
    local button = vgui.Create('fl_button', self.range_buttons)
    button:SetSize(icon_size, icon_size)
    button:SetDrawBackground(true)
    button:set_icon(v.icon)
    button:set_icon_size(icon_size * 0.8, icon_size * 0.8)
    button:set_centered(true)
    button:SetTooltip(v.name)
    button:Dock(RIGHT)
    button:DockMargin(margin, 0, 0, 0)
    button.type = k
    button.DoClick = function(btn)
      if self.range then
        self.range:set_active(false)
      end

      self.range = btn

      btn:set_active(true)
    end

    self.ranges[k] = button
  end

  self.range_label = vgui.Create('DLabel', self.range_buttons)
  self.range_label:Dock(RIGHT)
  self.range_label:SetText(t'ui.recognize.range'..': ')
  self.range_label:SetFont(Theme.get_font('text_normal_smaller'))
  self.range_label:SetTextColor(Theme.get_color('schema_text'))
  self.range_label:SizeToContentsX()

  total_height = total_height + icon_size + margin

  self.real_name_button = vgui.Create('fl_button', self.list)
  self.real_name_button:SetFont(Theme.get_font('text_normal_smaller'))
  self.real_name_button:DockMargin(0, margin, 0, margin)
  self.real_name_button:Dock(TOP)
  self.real_name_button:SetTall(scale(24))
  self.real_name_button:set_text(t'ui.recognize.character_name')
  self.real_name_button:set_centered(true)
  self.real_name_button.DoClick = function(btn)
    surface.PlaySound('buttons/blip1.wav')

    Cable.send('fl_recognize', self.range.type)

    self:safe_remove()
  end

  total_height = total_height + self.real_name_button:GetTall() + margin

  local history = Data.load('name_history/'..PLAYER:name(true), {})

  self.fake_name = vgui.Create('fl_base_panel', self.list)
  self.fake_name:SetTall(scale(24))
  self.fake_name:DockMargin(0, 0, 0, margin)
  self.fake_name:Dock(TOP)

  self.fake_name.text_entry = vgui.Create('DTextEntry', self.fake_name)
  self.fake_name.text_entry:SetSize(self:GetWide() * 0.5 - margin, self.fake_name:GetTall())
  self.fake_name.text_entry:SetFont(Theme.get_font('main_menu_normal'))
  self.fake_name.text_entry:SetText(PLAYER:name(true))

  self.fake_name.button = vgui.Create('fl_button', self.fake_name)
  self.fake_name.button:MoveRightOf(self.fake_name.text_entry, margin)
  self.fake_name.button:SetSize(self:GetWide() * 0.5 - margin, self.fake_name:GetTall())
  self.fake_name.button:SetFont(Theme.get_font('text_normal_smaller'))
  self.fake_name.button:set_text(t'ui.recognize.fake_name')
  self.fake_name.button:set_centered(true)
  self.fake_name.button.DoClick = function(btn)
    local text = self.fake_name.text_entry:GetValue()

    surface.PlaySound('buttons/blip1.wav')

    if text and text != '' then
      Cable.send('fl_recognize', self.range.type, text)

      if text != PLAYER:name(true) and !table.HasValue(history, text) then
        table.insert(history, 1, text)

        if #history > 5 then
          table.remove(history, 6)
        end

        Data.save('name_history/'..PLAYER:name(true), history)
      end
    end

    self:safe_remove()
  end

  total_height = total_height + self.fake_name:GetTall()

  if history and #history > 0 then
    self.name_history = vgui.Create('DListView', self.list)
    self.name_history:Dock(TOP)
    self.name_history:AddColumn(t'ui.recognize.previous_names'..':')

    for k, v in pairs(history) do
      self.name_history:AddLine(v)
    end

    self.name_history.OnRowSelected = function(list, index, line)
      self.fake_name.text_entry:SetValue(line:GetColumnText(1))
    end

    self.name_history:SetTall((#self.name_history:GetLines() + 1) * scale(17))

    total_height = total_height + self.name_history:GetTall() + margin
  end

  self:SetTall(total_height)

  if IsValid(PLAYER:GetEyeTraceNoCursor().Entity) then
    self.ranges['target']:DoClick()
  else
    self.ranges['talk']:DoClick()
  end
end

--- Closes the menu when F2 is pressed.
-- @param key [Number KEY_ enum of the pressed key]
function PANEL:OnKeyCodePressed(key)
  if key == KEY_F2 then
    self:safe_remove()
  end
end

vgui.Register('fl_recognize', PANEL, 'fl_frame')
