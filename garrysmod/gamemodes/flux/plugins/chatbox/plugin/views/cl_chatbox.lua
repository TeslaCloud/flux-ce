local PANEL = {}
PANEL.history = {}
PANEL.lastPos = 0
PANEL.isOpen = false

function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scrollPanel = vgui.Create('DScrollPanel', self)

  self.scrollPanel.Paint = function() return true end
  self.scrollPanel.VBar.Paint = function() return true end
  self.scrollPanel.VBar.btnUp.Paint = function() return true end
  self.scrollPanel.VBar.btnDown.Paint = function() return true end
  self.scrollPanel.VBar.btnGrip.Paint = function() return true end

  self.scrollPanel.VBar:SetWide(0)

  self.scrollPanel:SetPos(0, 0)
  self.scrollPanel:SetSize(w, h)
  self.scrollPanel:PerformLayout()

  self.text_entry = vgui.Create('fl_text_entry', self)
  self.text_entry:SetText('')
  self.text_entry:SetSize(1, 1)
  self.text_entry.history = {}
  self.text_entry.lastIndex = 0

  self.text_entry.OnValueChange = function(entry, value)
    hook.run('ChatTextChanged', value)
  end

  self.text_entry.OnEnter = function(entry)
    local value = entry:GetValue()

    hook.run('ChatboxTextEntered', value)

    if entry.history[1] != value then
      table.insert(entry.history, 1, value)

      entry.lastIndex = 1
    end

    entry:SetText('')
  end

  self.text_entry.OnKeyCodeTyped = function(entry, code)
    local shouldSet = false

    if code == KEY_ENTER then
      entry:OnEnter()

      return true
    elseif code == KEY_DOWN then
      if entry.lastIndex == 1 then
        entry.lastIndex = #entry.history
      else
        entry.lastIndex = math.Clamp(entry.lastIndex - 1, 1, #entry.history)
      end

      shouldSet = true
    elseif code == KEY_UP then
      if entry.lastIndex == #entry.history then
        entry.lastIndex = 1
      else
        entry.lastIndex = math.Clamp(entry.lastIndex + 1, 1, #entry.history)
      end

      shouldSet = true
    end

    local historyEntry = entry.history[entry.lastIndex]

    if historyEntry and historyEntry != '' and shouldSet then
      entry:SetText(historyEntry)
      entry:SetCaretPos(string.utf8len(historyEntry))

      return true
    end
  end

  self:Rebuild()
end

function PANEL:SetOpen(bIsOpen)
  self.isOpen = bIsOpen

  if bIsOpen then
    self:MakePopup()

    self.text_entry:SetVisible(true)
    self.text_entry:RequestFocus()
    self.text_entry.lastIndex = 0
  else
    if self.text_entry:GetValue():is_command() then
      self.text_entry:SetText('')
    end

    self:KillFocus()

    self.text_entry:SetVisible(false)
  end

  for k, v in ipairs(self.history) do
    v.forceShow = bIsOpen
  end
end

function PANEL:IsTypingCommand()
  if IsValid(self.text_entry) then
    local cmd = self.text_entry:GetValue()

    if cmd != '/' then
      return cmd:is_command()
    end
  end
end

function PANEL:CreateMessage(messageData)
  local parsed = chatbox.Compile(messageData)

  if !parsed then return end

  local panel = vgui.Create('flChatMessage', self)

  panel:SetSize(self:GetWide(), self:GetWide()) -- Width is placeholder and is later set by compiled message table.
  panel:SetMessage(parsed)

  return panel
end

function PANEL:AddMessage(messageData)
  if messageData and plugin.call('ChatboxShouldAddMessage', messageData) != false then
    local panel = self:CreateMessage(messageData)

    if IsValid(panel) then
      self:AddPanel(panel)
    end
  end
end

function PANEL:AddPanel(panel)
  if #self.history >= config.get('chatbox_max_messages') then
    self.history[1]:Eject()
  end

  local idx = table.insert(self.history, panel)

  panel:SetPos(0, self.lastPos)
  panel.messageIndex = idx

  self.scrollPanel:AddItem(panel)

  self.lastPos = self.lastPos + config.get('chatbox_message_margin') + panel:GetTall()
end

function PANEL:RemoveMessage(idx)
  table.remove(self.history, idx)
end

function PANEL:Rebuild()
  self:SetSize(chatbox.width, chatbox.height)
  self:SetPos(chatbox.x, chatbox.y)

  self.text_entry:SetSize(chatbox.width, 20)
  self.text_entry:SetPos(0, chatbox.height - 20)
  self.text_entry:SetFont(theme.GetFont('text_small'))
  self.text_entry:SetTextColor(theme.GetColor('text'))
  self.text_entry:RequestFocus()

  self.scrollPanel:SetSize(chatbox.width, chatbox.height - self.text_entry:GetTall() - 16)
  self.scrollPanel:PerformLayout()
  self.scrollPanel.VBar:SetScroll(self.scrollPanel.VBar.CanvasSize or 0)

  self.lastPos = 0

  -- Reversed ipairs anyone?????
  for i = #self.history, 1, -1 do
    local v = self.history[i]

    v:SetPos(0, self.lastPos)

    self.lastPos = self.lastPos + config.get('chatbox_message_margin') + v:GetTall()
  end
end

function PANEL:Think()
  if self.isOpen then
    if input.IsKeyDown(KEY_ESCAPE) then
      chatbox.Hide()

      if gui.IsGameUIVisible() then
        gui.HideGameUI()
      end
    end
  else
    self.scrollPanel.VBar:SetScroll(self.scrollPanel.VBar.CanvasSize)
  end
end

function PANEL:Paint(w, h)
  plugin.call('ChatboxPaintBackground', w, h, self)
end

function PANEL:PaintOver(w, h)
  if plugin.call('ChatboxPaintOver', w, h, self) == nil then
    local entry = self.text_entry

    if IsValid(entry) then
      local val = entry:GetValue()
      local isCommand, prefixLen = string.is_command(val)

      if isCommand then
        local space = string.find(val, ' ')
        local endpos = space

        if !endpos then
          endpos = (string.len(val) + 1)
        end

        local cmd = string.utf8lower(string.sub(val, prefixLen + 1, endpos - 1))
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

        local font, color = theme.GetFont('text_normal'), theme.GetColor('accent')

        if #cmds > 0 then
          local lastY = 0
          local color_white = Color(255, 255, 255)

          for k, v in ipairs(cmds) do
            local w, h = draw.SimpleText('/' + v.name, font, 16, 16 + lastY, color)
            w, h = draw.SimpleText(v.syntax, font, 16 + w + 8, 16 + lastY, color_white)

            if #cmds == 1 then
              local smallFont = theme.GetFont('text_small')
              local w2, h2 = draw.SimpleText(v.description, smallFont, 16, 16 + h + 4, color_white)
              local aliases = '[none]'

              if v.aliases and #v.aliases > 0 then
                aliases = table.concat(v.aliases or {}, ', ')
              end

              draw.SimpleText('Aliases: ' + aliases, smallFont, 16, 16 + h + h2 + 4, color_white)
            end

            lastY = lastY + h + 8

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
