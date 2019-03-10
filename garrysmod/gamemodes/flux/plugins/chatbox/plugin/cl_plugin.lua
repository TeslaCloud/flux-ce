local category = Config.create_category('chatbox', 'config.chatbox.title', 'config.chatbox.desc')
category.add_slider('chatbox_message_margin', 'config.chatbox.margin.name', 'config.chatbox.margin.desc', { min = 0, max = 64, default = 2 })
category.add_slider('chatbox_message_fade_delay', 'config.chatbox.fade_delay.name', 'config.chatbox.fade_delay.desc', { min = 1, max = 128, default = 12 })
category.add_slider('chatbox_max_messages', 'config.chatbox.max_messages.name', 'config.chatbox.max_messages.desc', { min = 1, max = 256, default = 100 })

chatbox.width = chatbox.width or 100
chatbox.height = chatbox.height or 100
chatbox.x = chatbox.x or 0
chatbox.y = chatbox.y or 0

chatbox.old_add_text = chatbox.old_add_text or chat.AddText

function chat.AddText(...)
  Cable.send('fl_chat_text_add', ...)
end

function chatbox.compile(msg_table)
  local compiled = {
    total_height = 0
  }

  local data = msg_table.data
  local should_translate = msg_table.should_translate
  local cur_size = Font.scale(18)

  if isnumber(msg_table.size) then
    cur_size = Font.scale(msg_table.size)
  end

  -- offset x by 1 to prevent weird clipping issues
  local cur_x, cur_y = 1, 0
  local total_height = 0
  local font = Font.size(Theme.get_font('chatbox_normal'), cur_size)

  if plugin.call('ChatboxCompileMessage', data, compiled) != true then
    for k, v in ipairs(data) do
      if plugin.call('ChatboxCompileMessageData', v, compiled) == true then
        continue
      end

      if isstring(v) then
        if should_translate then
          data[k] = t(v)
        end

        local wrapped = util.wrap_text(v, font, chatbox.width, cur_x)
        local line_count = #wrapped

        for k2, v2 in ipairs(wrapped) do
          local w, h = util.text_size(v2, font)

          table.insert(compiled, { text = v2, w = w, h = h, x = cur_x, y = cur_y })

          cur_x = cur_x + w

          if line_count > 1 and k2 != line_count then
            cur_y = cur_y + h + Config.get('chatbox_message_margin')

            total_height = total_height + h + Config.get('chatbox_message_margin')

            cur_x = 0
          elseif total_height < h then
            total_height = h + Config.get('chatbox_message_margin')
          end
        end
      elseif isnumber(v) then
        cur_size = Font.scale(v)

        font = Font.size(Theme.get_font('chatbox_normal'), cur_size)

        table.insert(compiled, cur_size)
      elseif istable(v) then
        if v.image then
          local scaled = Font.scale(v.height)
          local image_data = {
            image = v.image,
            x = cur_x + 1,
            y = cur_y,
            w = Font.scale(v.width),
            h = scaled
          }

          cur_x = cur_x + image_data.w + 2

          table.insert(compiled, image_data)

          if total_height < scaled then
            total_height = scaled + Config.get('chatbox_message_margin')
          end
        elseif v.r and v.g and v.b and v.a then
          table.insert(compiled, Color(v.r, v.g, v.b, v.a))
        end
      elseif IsValid(v) then
        local to_insert = ''

        if v:IsPlayer() then
          to_insert = hook.run('GetPlayerName', v) or v:name()
        else
          to_insert = tostring(v) or v:GetClass()
        end

        local w, h = util.text_size(to_insert, font)

        table.insert(compiled, {text = to_insert, w = w, h = h, x = cur_x, y = cur_y})

        cur_x = cur_x + w

        if total_height < h then
          total_height = h + Config.get('chatbox_message_margin')
        end
      end
    end
  end

  compiled.total_height = math.max(total_height, compiled.total_height)

  return compiled
end

function chatbox.create()
  chatbox.width = Theme.get_option('chatbox_width') or 100
  chatbox.height = Theme.get_option('chatbox_height') or 100
  chatbox.x = Theme.get_option('chatbox_x') or 0
  chatbox.y = Theme.get_option('chatbox_y') or 0

  chatbox.panel = vgui.Create('fl_chat_panel')
  chatbox.panel:set_open(false)
end

function chatbox.show()
  if !IsValid(chatbox.panel) then
    chatbox.create()
  end

  chatbox.panel:set_open(true)
end

function chatbox.hide()
  if IsValid(chatbox.panel) then
    chatbox.panel:set_open(false)

    chatbox.panel:SetMouseInputEnabled(false)
    chatbox.panel:SetKeyboardInputEnabled(false)
  end
end

concommand.Add('fl_reset_chat', function()
  if IsValid(chatbox.panel) then
    chatbox.panel:safe_remove()
  end
end)
