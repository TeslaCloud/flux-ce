--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local PANEL = {}
PANEL.history = {}
PANEL.lastPos = 0
PANEL.isOpen = false

function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scrollPanel = vgui.Create("DScrollPanel", self)

  self.scrollPanel.Paint = function() return true end
  self.scrollPanel.VBar.Paint = function() return true end
  self.scrollPanel.VBar.btnUp.Paint = function() return true end
  self.scrollPanel.VBar.btnDown.Paint = function() return true end
  self.scrollPanel.VBar.btnGrip.Paint = function() return true end

  self.scrollPanel.VBar:SetWide(0)

  self.scrollPanel:SetPos(0, 0)
  self.scrollPanel:SetSize(w, h)
  self.scrollPanel:PerformLayout()

  self.textEntry = vgui.Create("flTextEntry", self)
  self.textEntry:SetText("")
  self.textEntry:SetSize(1, 1)
  self.textEntry.history = {}
  self.textEntry.lastIndex = 0

  self.textEntry.OnValueChange = function(entry, value)
    hook.Run("ChatTextChanged", value)
  end

  self.textEntry.OnEnter = function(entry)
    local value = entry:GetValue()

    hook.Run("ChatboxTextEntered", value)

    if (entry.history[1] != value) then
      table.insert(entry.history, 1, value)

      entry.lastIndex = 1
    end

    entry:SetText("")
  end

  self.textEntry.OnKeyCodeTyped = function(entry, code)
    local shouldSet = false

    if (code == KEY_ENTER) then
      entry:OnEnter()

      return true
    elseif (code == KEY_DOWN) then
      if (entry.lastIndex == 1) then
        entry.lastIndex = #entry.history
      else
        entry.lastIndex = math.Clamp(entry.lastIndex - 1, 1, #entry.history)
      end

      shouldSet = true
    elseif (code == KEY_UP) then
      if (entry.lastIndex == #entry.history) then
        entry.lastIndex = 1
      else
        entry.lastIndex = math.Clamp(entry.lastIndex + 1, 1, #entry.history)
      end

      shouldSet = true
    end

    local historyEntry = entry.history[entry.lastIndex]

    if (historyEntry and historyEntry != "" and shouldSet) then
      entry:SetText(historyEntry)
      entry:SetCaretPos(string.utf8len(historyEntry))

      return true
    end
  end

  self:Rebuild()
end

function PANEL:SetOpen(bIsOpen)
  self.isOpen = bIsOpen

  if (bIsOpen) then
    self:MakePopup()

    self.textEntry:SetVisible(true)
    self.textEntry:RequestFocus()
    self.textEntry.lastIndex = 0
  else
    if (self.textEntry:GetValue():IsCommand()) then
      self.textEntry:SetText("")
    end

    self:KillFocus()

    self.textEntry:SetVisible(false)
  end

  for k, v in ipairs(self.history) do
    v.forceShow = bIsOpen
  end
end

function PANEL:IsTypingCommand()
  if (IsValid(self.textEntry)) then
    local cmd = self.textEntry:GetValue()

    if (cmd != "/") then
      return cmd:IsCommand()
    end
  end
end

function PANEL:CreateMessage(messageData)
  local parsed = chatbox.Compile(messageData)

  if (!parsed) then return end

  local panel = vgui.Create("flChatMessage", self)

  panel:SetSize(self:GetWide(), self:GetWide()) -- Width is placeholder and is later set by compiled message table.
  panel:SetMessage(parsed)

  return panel
end

function PANEL:AddMessage(messageData)
  if (messageData and plugin.call("ChatboxShouldAddMessage", messageData) != false) then
    local panel = self:CreateMessage(messageData)

    if (IsValid(panel)) then
      self:AddPanel(panel)
    end
  end
end

function PANEL:AddPanel(panel)
  if (#self.history >= config.Get("chatbox_max_messages")) then
    self.history[1]:Eject()
  end

  local idx = table.insert(self.history, panel)

  panel:SetPos(0, self.lastPos)
  panel.messageIndex = idx

  self.scrollPanel:AddItem(panel)

  self.lastPos = self.lastPos + config.Get("chatbox_message_margin") + panel:GetTall()
end

function PANEL:RemoveMessage(idx)
  table.remove(self.history, idx)
end

function PANEL:Rebuild()
  self:SetSize(chatbox.width, chatbox.height)
  self:SetPos(chatbox.x, chatbox.y)

  self.textEntry:SetSize(chatbox.width, 20)
  self.textEntry:SetPos(0, chatbox.height - 20)
  self.textEntry:SetFont(theme.GetFont("Text_Small"))
  self.textEntry:SetTextColor(theme.GetColor("Text"))
  self.textEntry:RequestFocus()

  self.scrollPanel:SetSize(chatbox.width, chatbox.height - self.textEntry:GetTall() - 16)
  self.scrollPanel:PerformLayout()
  self.scrollPanel.VBar:SetScroll(self.scrollPanel.VBar.CanvasSize or 0)

  self.lastPos = 0

  -- Reversed ipairs anyone?????
  for i = #self.history, 1, -1 do
    local v = self.history[i]

    v:SetPos(0, self.lastPos)

    self.lastPos = self.lastPos + config.Get("chatbox_message_margin") + v:GetTall()
  end
end

function PANEL:Think()
  if (self.isOpen) then
    if (input.IsKeyDown(KEY_ESCAPE)) then
      chatbox.Hide()

      if (gui.IsGameUIVisible()) then
        gui.HideGameUI()
      end
    end
  else
    self.scrollPanel.VBar:SetScroll(self.scrollPanel.VBar.CanvasSize)
  end
end

function PANEL:Paint(w, h)
  plugin.call("ChatboxPaintBackground", w, h, self)
end

function PANEL:PaintOver(w, h)
  if (plugin.call("ChatboxPaintOver", w, h, self) == nil) then
    local entry = self.textEntry

    if (IsValid(entry)) then
      local val = entry:GetValue()
      local isCommand, prefixLen = string.IsCommand(val)

      if (isCommand) then
        local space = string.find(val, " ")
        local endpos = space

        if (!endpos) then
          endpos = (string.len(val) + 1)
        end

        local cmd = string.utf8lower(string.sub(val, prefixLen + 1, endpos - 1))
        local cmds = {}

        if (cmd == "" or cmd == " ") then return end

        if (!space) then
          cmds = fl.command:FindAll(cmd)
        else
          local found = fl.command:FindByID(cmd)

          if (found) then
            table.insert(cmds, found)
          end
        end

        draw.RoundedBox(0, 0, 0, w, h - entry:GetTall(), Color(0, 0, 0, 150))

        local font, color = theme.GetFont("Text_Normal"), theme.GetColor("Accent")

        if (#cmds > 0) then
          local lastY = 0
          local color_white = Color(255, 255, 255)

          for k, v in ipairs(cmds) do
            local w, h = draw.SimpleText("/" + v.Name, font, 16, 16 + lastY, color)
            w, h = draw.SimpleText(v.Syntax, font, 16 + w + 8, 16 + lastY, color_white)

            if (#cmds == 1) then
              local smallFont = theme.GetFont("Text_Small")
              local w2, h2 = draw.SimpleText(v.Description, smallFont, 16, 16 + h + 4, color_white)
              local aliases = "[none]"

              if (v.Aliases and #v.Aliases > 0) then
                aliases = table.concat(v.Aliases or {}, ", ")
              end

              draw.SimpleText("Aliases: " + aliases, smallFont, 16, 16 + h + h2 + 4, color_white)
            end

            lastY = lastY + h + 8

            if (k >= 10) then break end
          end
        else
          draw.SimpleText("No commands found!", font, 16, 16, color)
        end
      end
    end
  end
end

vgui.Register("flChatPanel", PANEL, "flBasePanel")
