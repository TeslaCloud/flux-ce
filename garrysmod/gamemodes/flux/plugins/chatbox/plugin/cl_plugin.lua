--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local CATEGORY = config.CreateCategory("chatbox", "Chatbox Settings", "Customize how the chat box works for your server!")
CATEGORY:AddSlider("chatbox_message_margin", "Chat Message Margin", "How much vertical space to put between two messages?", {min = 0, max = 64, default = 2})
CATEGORY:AddSlider("chatbox_message_fade_delay", "Chat Message Fade Delay", "How long do the messages stay on the screen before fading away?", {min = 1, max = 128, default = 12})
CATEGORY:AddSlider("chatbox_max_messages", "Max Chat Messages", "How much messages should the chat history hold?", {min = 1, max = 256, default = 100})

chatbox.width = chatbox.width or 100
chatbox.height = chatbox.height or 100
chatbox.x = chatbox.x or 0
chatbox.y = chatbox.y or 0

chatbox.oldAddText = chatbox.oldAddText or chat.AddText

function chat.AddText(...)
  netstream.Start("Chatbox::AddText", ...)
end

function chatbox.Compile(messageTable)
  local compiled = {
    totalHeight = 0
  }

  local data = messageTable.data
  local shouldTranslate = messageTable.shouldTranslate
  local curSize = _font.Scale(18)

  if (isnumber(messageTable.size)) then
    curSize = _font.Scale(messageTable.size)
  end

  local curX, curY = 0, 0
  local totalHeight = 0
  local maxHeight = font.Scale(messageTable.maxHeight)
  local font = _font.GetSize(theme.GetFont("Chatbox_Normal"), curSize)

  if (plugin.call("ChatboxCompileMessage", data, compiled) != true) then
    for k, v in ipairs(data) do
      if (plugin.call("ChatboxCompileMessageData", v, compiled) == true) then
        continue
      end

      if (isstring(v)) then
        if (shouldTranslate) then
          data[k] = fl.lang:TranslateText(v)
        end

        local wrapped = util.WrapText(v, font, chatbox.width, curX)
        local nWrapped = #wrapped

        for k2, v2 in ipairs(wrapped) do
          local w, h = util.GetTextSize(v2, font)

          table.insert(compiled, {text = v2, w = w, h = h, x = curX, y = curY + (maxHeight - h)})

          curX = curX + w

          if (nWrapped > 1 and k2 != nWrapped) then
            curY = curY + h + config.Get("chatbox_message_margin")

            totalHeight = totalHeight + h + config.Get("chatbox_message_margin")

            curX = 0
          elseif (totalHeight < h) then
            totalHeight = h
          end
        end
      elseif (isnumber(v)) then
        curSize = _font.Scale(v)

        font = _font.GetSize(theme.GetFont("Chatbox_Normal"), curSize)

        table.insert(compiled, curSize)
      elseif (istable(v)) then
        if (v.image) then
          local scaled = _font.Scale(v.height)
          local imageData = {
            image = v.image,
            x = curX + 1,
            y = curY,
            w = _font.Scale(v.width),
            h = scaled
          }

          curX = curX + imageData.w + 2

          table.insert(compiled, imageData)

          if (totalHeight < scaled) then
            totalHeight = scaled
          end
        elseif (v.r and v.g and v.b and v.a) then
          table.insert(compiled, Color(v.r, v.g, v.b, v.a))
        end
      elseif (IsValid(v)) then
        local toInsert = ""

        if (v:IsPlayer()) then
          toInsert = hook.Run("GetPlayerName", v) or v:Name()
        else
          toInsert = tostring(v) or v:GetClass()
        end

        local w, h = util.GetTextSize(toInsert, font)

        table.insert(compiled, {text = toInsert, w = w, h = h, x = curX, y = curY + (maxHeight - h)})

        curX = curX + w

        if (totalHeight < h) then
          totalHeight = h
        end
      end
    end
  end

  compiled.totalHeight = math.max(totalHeight, compiled.totalHeight)

  return compiled
end

function chatbox.Show()
  if (!IsValid(chatbox.panel)) then
    chatbox.width = theme.GetOption("Chatbox_Width") or 100
    chatbox.height = theme.GetOption("Chatbox_Height") or 100
    chatbox.x = theme.GetOption("Chatbox_X") or 0
    chatbox.y = theme.GetOption("Chatbox_Y") or 0

    chatbox.panel = vgui.Create("flChatPanel")
  end

  chatbox.panel:SetOpen(true)
end

function chatbox.Hide()
  if (IsValid(chatbox.panel)) then
    chatbox.panel:SetOpen(false)

    chatbox.panel:SetMouseInputEnabled(false)
    chatbox.panel:SetKeyboardInputEnabled(false)
  end
end

concommand.Add("fl_reset_chat", function()
  if (IsValid(chatbox.panel)) then
    chatbox.panel:SafeRemove()
  end
end)
