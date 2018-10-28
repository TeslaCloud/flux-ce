local PANEL = {}
PANEL.history = {}
PANEL.last_pos = 0
PANEL.is_open = false
PANEL.padding = 8

function PANEL:set_open(is_open)
  self.is_open = is_open

  if is_open then
    self:MakePopup()

    self.text_entry:SetVisible(true)
    self.text_entry:RequestFocus()
    self.text_entry.last_index = 0
  else
    if self.text_entry:GetValue():is_command() then
      self.text_entry:SetText('')
    end

    self:KillFocus()

    self.text_entry:SetVisible(false)
  end

  for k, v in ipairs(self.history) do
    if IsValid(v) then
      v.force_show = is_open
    end
  end
end

function PANEL:typing_command()
  if IsValid(self.text_entry) then
    local cmd = self.text_entry:GetValue()

    if cmd != '/' then
      return cmd:is_command()
    end
  end
end

function PANEL:create_message(message_data)
  local parsed = chatbox.compile(message_data)

  if !parsed then return end

  local panel = vgui.Create('fl_chat_message', self)
  local half_padding = self.padding * 0.5

  panel:SetSize(self:GetWide() - half_padding, self:GetWide() - half_padding) -- Width is placeholder and is later set by compiled message table.
  panel:set_message(parsed)

  return panel
end

function PANEL:add_message(message_data)
  if message_data and plugin.call('ChatboxShouldAddMessage', message_data) != false then
    local panel = self:create_message(message_data)

    if IsValid(panel) then
      self:add_panel(panel)

      timer.Simple(0.05, function()
        local scroll = self.scroll_panel
        local value = panel:GetTall() + self.padding

        if scroll:GetCanvas():GetTall() - scroll:GetTall() - scroll.VBar:GetScroll() <= value then
          self.scroll_panel.VBar:AddScroll(value)
        end
      end)
    end
  end
end

function PANEL:rebuild_history_indexes()
  local new_history = {}

  for k, v in ipairs(self.history) do
    if IsValid(v) then
      local idx = table.insert(new_history, v)
      v.msg_index = idx
    end
  end

  self.history = new_history
  self:Rebuild()
end

function PANEL:add_panel(panel)
  if #self.history >= config.get('chatbox_max_messages') then
    local last_history = self.history[1]

    if IsValid(last_history) then
      last_history:eject()
    else
      self:rebuild_history_indexes()
    end
  end

  local idx = table.insert(self.history, panel)

  panel:SetPos(self.padding, self.last_pos)
  panel.msg_index = idx

  self.scroll_panel:AddItem(panel)

  self.last_pos = self.last_pos + config.get('chatbox_message_margin') + panel:GetTall()
end

function PANEL:remove_message(idx)
  table.remove(self.history, idx)
  self:rebuild_history_indexes()
end

function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.scroll_panel.Paint = function() return true end
  self.scroll_panel.VBar.Paint = function() return true end
  self.scroll_panel.VBar.btnUp.Paint = function() return true end
  self.scroll_panel.VBar.btnDown.Paint = function() return true end
  self.scroll_panel.VBar.btnGrip.Paint = function() return true end

  self.scroll_panel.VBar:SetWide(0)

  self.scroll_panel:SetPos(0, 0)
  self.scroll_panel:SetSize(w, h)
  self.scroll_panel:PerformLayout()

  self.text_entry = vgui.Create('fl_text_entry', self)
  self.text_entry:SetText('')
  self.text_entry:SetSize(1, 1)
  self.text_entry.history = {}
  self.text_entry.last_index = 0

  self.text_entry.OnValueChange = function(entry, value)
    hook.run('ChatTextChanged', value)
  end

  self.text_entry.OnEnter = function(entry)
    local value = entry:GetValue()

    hook.run('ChatboxTextEntered', value)

    if entry.history[1] != value then
      table.insert(entry.history, 1, value)

      entry.last_index = 1
    end

    entry:SetText('')
  end

  self.text_entry.OnKeyCodeTyped = function(entry, code)
    local should_set = false

    if code == KEY_ENTER then
      entry:OnEnter()

      return true
    elseif code == KEY_DOWN then
      if entry.last_index == 1 then
        entry.last_index = #entry.history
      else
        entry.last_index = math.Clamp(entry.last_index - 1, 1, #entry.history)
      end

      should_set = true
    elseif code == KEY_UP then
      if entry.last_index == #entry.history then
        entry.last_index = 1
      else
        entry.last_index = math.Clamp(entry.last_index + 1, 1, #entry.history)
      end

      should_set = true
    end

    local historyEntry = entry.history[entry.last_index]

    if historyEntry and historyEntry != '' and should_set then
      entry:SetText(historyEntry)
      entry:SetCaretPos(string.utf8len(historyEntry))

      return true
    end
  end

  self:Rebuild()
end

function PANEL:Rebuild()
  self:SetSize(chatbox.width, chatbox.height)
  self:SetPos(chatbox.x, chatbox.y)

  self.text_entry:SetSize(chatbox.width, 20)
  self.text_entry:SetPos(0, chatbox.height - 20)
  self.text_entry:SetFont(theme.get_font('text_small'))
  self.text_entry:SetTextColor(theme.get_color('text'))
  self.text_entry:RequestFocus()

  self.scroll_panel:SetSize(chatbox.width, chatbox.height - self.text_entry:GetTall() - 16)
  self.scroll_panel:PerformLayout()
  self.scroll_panel.VBar:SetScroll(self.scroll_panel.VBar.CanvasSize or 0)

  self.last_pos = 0

  for k, v in ipairs(self.history) do
    if IsValid(v) then
      v:SetPos(self.padding, self.last_pos)

      self.last_pos = self.last_pos + config.get('chatbox_message_margin') + v:GetTall()
    end
  end
end

function PANEL:Think()
  if self.is_open then
    if input.IsKeyDown(KEY_ESCAPE) then
      chatbox.hide()

      if gui.IsGameUIVisible() then
        gui.HideGameUI()
      end
    end
  else
    self.scroll_panel.VBar:SetScroll(self.scroll_panel.VBar.CanvasSize)
  end
end

function PANEL:Paint(w, h)
  if self.is_open then
    theme.hook('ChatboxPaintBackground', self, w, h)
  end
end

function PANEL:PaintOver(w, h)
  if theme.hook('ChatboxPaintOver', self, w, h) == nil then
    local entry = self.text_entry

    if IsValid(entry) then
      local val = entry:GetValue()
      local is_command, prefix_len = string.is_command(val)

      if is_command then
        local space = string.find(val, ' ')
        local endpos = space

        if !endpos then
          endpos = (string.len(val) + 1)
        end

        local cmd = string.utf8lower(string.sub(val, prefix_len + 1, endpos - 1))
        local cmds = {}

        if cmd == '' or cmd == ' ' then return end

        if !space then
          cmds = fl.command:find_all(cmd)
        else
          local found = fl.command:find_by_id(cmd)

          if found then
            table.insert(cmds, found)
          end
        end

        draw.RoundedBox(0, 0, 0, w, h - entry:GetTall(), Color(0, 0, 0, 150))

        local font, color = theme.get_font('text_normal'), theme.get_color('accent')

        if #cmds > 0 then
          local last_y = 0
          local color_white = Color(255, 255, 255)

          for k, v in ipairs(cmds) do
            local w, h = draw.SimpleText('/' + v.name, font, 16, 16 + last_y, color)
            w, h = draw.SimpleText(v.syntax, font, 16 + w + 8, 16 + last_y, color_white)

            if #cmds == 1 then
              local small_font = theme.get_font('text_small')
              local w2, h2 = draw.SimpleText(v.description, small_font, 16, 16 + h + 4, color_white)
              local aliases = '[-]'

              if v.aliases and #v.aliases > 0 then
                aliases = table.concat(v.aliases or {}, ', ')
              end

              draw.SimpleText('Aliases: ' + aliases, small_font, 16, 16 + h + h2 + 4, color_white)
            end

            last_y = last_y + h + 8

            if k >= 10 then break end
          end
        else
          draw.SimpleText('No commands found!', font, 16, 16, color)
        end
      end
    end
  end
end

vgui.Register('flChatPanel', PANEL, 'fl_base_panel')
