local CATEGORY = config.create_category('chatbox', 'Chatbox Settings', 'Customize how the chat box works for your server!')
CATEGORY:add_slider('chatbox_message_margin', 'Chat Message Margin', 'How much vertical space to put between two messages?', {min = 0, max = 64, default = 2})
CATEGORY:add_slider('chatbox_message_fade_delay', 'Chat Message Fade Delay', 'How long do the messages stay on the screen before fading away?', {min = 1, max = 128, default = 12})
CATEGORY:add_slider('chatbox_max_messages', 'Max Chat Messages', 'How much messages should the chat history hold?', {min = 1, max = 256, default = 100})

chatbox.width = chatbox.width or 100
chatbox.height = chatbox.height or 100
chatbox.x = chatbox.x or 0
chatbox.y = chatbox.y or 0

chatbox.oldAddText = chatbox.oldAddText or chat.AddText

function chat.AddText(...)
  netstream.Start('Chatbox::AddText', ...)
end

function chatbox.Compile(messageTable)
  local compiled = {
    total_height = 0
  }

  local data = messageTable.data
  local should_translate = messageTable.should_translate
  local cur_size = _font.Scale(18)

  if isnumber(messageTable.size) then
    cur_size = _font.Scale(messageTable.size)
  end

  local curX, curY = 0, 0
  local total_height = 0
  local max_height = font.Scale(messageTable.max_height)
  local font = _font.GetSize(theme.GetFont('Chatbox_Normal'), cur_size)

  if plugin.call('ChatboxCompileMessage', data, compiled) != true then
    for k, v in ipairs(data) do
      if plugin.call('ChatboxCompileMessageData', v, compiled) == true then
        continue
      end

      if isstring(v) then
        if should_translate then
          data[k] = t(v)
        end

        local wrapped = util.wrap_text(v, font, chatbox.width, curX)
        local line_count = #wrapped

        for k2, v2 in ipairs(wrapped) do
          local w, h = util.text_size(v2, font)

          table.insert(compiled, {text = v2, w = w, h = h, x = curX, y = curY + (max_height - h)})

          curX = curX + w

          if line_count > 1 and k2 != line_count then
            curY = curY + h + config.get('chatbox_message_margin')

            total_height = total_height + h + config.get('chatbox_message_margin')

            curX = 0
          elseif total_height < h then
            total_height = h + config.get('chatbox_message_margin')
          end
        end
      elseif isnumber(v) then
        cur_size = _font.Scale(v)

        font = _font.GetSize(theme.GetFont('Chatbox_Normal'), cur_size)

        table.insert(compiled, cur_size)
      elseif istable(v) then
        if v.image then
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

          if total_height < scaled then
            total_height = scaled + config.get('chatbox_message_margin')
          end
        elseif v.r and v.g and v.b and v.a then
          table.insert(compiled, Color(v.r, v.g, v.b, v.a))
        end
      elseif IsValid(v) then
        local toInsert = ''

        if v:IsPlayer() then
          toInsert = hook.run('GetPlayerName', v) or v:Name()
        else
          toInsert = tostring(v) or v:GetClass()
        end

        local w, h = util.text_size(toInsert, font)

        table.insert(compiled, {text = toInsert, w = w, h = h, x = curX, y = curY + (max_height - h)})

        curX = curX + w

        if total_height < h then
          total_height = h + config.get('chatbox_message_margin')
        end
      end
    end
  end

  compiled.total_height = math.max(total_height, compiled.total_height)

  return compiled
end

function chatbox.Show()
  if !IsValid(chatbox.panel) then
    chatbox.width = theme.GetOption('Chatbox_Width') or 100
    chatbox.height = theme.GetOption('Chatbox_Height') or 100
    chatbox.x = theme.GetOption('Chatbox_X') or 0
    chatbox.y = theme.GetOption('Chatbox_Y') or 0

    chatbox.panel = vgui.Create('flChatPanel')
  end

  chatbox.panel:SetOpen(true)
end

function chatbox.Hide()
  if IsValid(chatbox.panel) then
    chatbox.panel:SetOpen(false)

    chatbox.panel:SetMouseInputEnabled(false)
    chatbox.panel:SetKeyboardInputEnabled(false)
  end
end

concommand.Add('fl_reset_chat', function()
  if IsValid(chatbox.panel) then
    chatbox.panel:SafeRemove()
  end
end)
