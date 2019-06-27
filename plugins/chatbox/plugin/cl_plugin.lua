local category = Config.create_category('chatbox', 'config.chatbox.title', 'config.chatbox.desc')
category.add_slider('chatbox_message_margin', 'config.chatbox.margin.name', 'config.chatbox.margin.desc', { min = 0, max = 64, default = 2 })
category.add_slider('chatbox_message_fade_delay', 'config.chatbox.fade_delay.name', 'config.chatbox.fade_delay.desc', { min = 1, max = 128, default = 12 })
category.add_slider('chatbox_max_messages', 'config.chatbox.max_messages.name', 'config.chatbox.max_messages.desc', { min = 1, max = 256, default = 100 })

Chatbox.width = Chatbox.width or 100
Chatbox.height = Chatbox.height or 100
Chatbox.x = Chatbox.x or 0
Chatbox.y = Chatbox.y or 0

Chatbox.old_add_text = Chatbox.old_add_text or chat.AddText

function chat.AddText(...)
  Cable.send('fl_chat_text_add', ...)
end

function Chatbox.compile(msg_table)
  local compiled = {
    total_height = 0
  }

  local data = msg_table.data
  local should_translate = msg_table.should_translate
  local cur_size = Theme.get_option('chatbox_text_normal_size')

  if isnumber(msg_table.size) then
    cur_size = math.scale(msg_table.size)
  end

  -- offset x by 1 to prevent weird clipping issues
  local cur_x, cur_y = 1, 0
  local total_height = 0
  local font = Font.size(Theme.get_font('chatbox_normal'), cur_size)
  local v_offset = 0
  local fix = Theme.get_option('chatbox_fix_alignment') == true
  local fix_const = 0.2 -- 4 * 0.05

  if !font then return end

  table.insert(compiled, cur_size)

  if Plugin.call('ChatboxCompileMessage', data, compiled) != true then
    for k, v in ipairs(data) do
      if Plugin.call('ChatboxCompileMessageData', v, compiled) == true then
        continue
      end

      if isstring(v) then
        if should_translate then
          data[k] = t(v)
        end

        local wrapped = util.wrap_text(v, font, Chatbox.width - Theme.get_option('chatbox_padding', math.scale(8)) * 4, cur_x)
        local line_count = #wrapped

        for k2, v2 in ipairs(wrapped) do
          local w, h = util.text_size(v2, font)

          if !fix then
            table.insert(compiled, { text = v2, w = w, h = h, x = cur_x, y = cur_y })
          else
            table.insert(compiled, { text = v2, w = w, h = h, x = cur_x, y = cur_y - h * fix_const })
            h = h - (h * fix_const)
          end

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
        cur_size = math.scale(v)

        font = Font.size(Theme.get_font('chatbox_normal'), cur_size)

        table.insert(compiled, cur_size)
      elseif istable(v) then
        if v.image or v.icon then
          v.height  = v.height  or v.size
          v.width   = v.width   or v.size

          local margin = math.scale(v.margin or 2)
          local margin_side = math.ceil(margin * 0.5)
          local scaled = math.scale(v.height)
          local image_data = {
            image = v.image,
            x     = cur_x + margin_side,
            y     = cur_y,
            w     = math.scale(v.width),
            h     = scaled
          }

          if v.icon then
            image_data.image  = nil 
            image_data.icon   = v.icon
          end

          cur_x = cur_x + image_data.w + margin

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
          to_insert = hook.run('ShouldProcessPlayerName', v, msg_table) != false and hook.run('GetPlayerName', v) or v:name(true)
        else
          to_insert = tostring(v) or v:GetClass()
        end

        local w, h = util.text_size(to_insert, font)

        if !fix then
          table.insert(compiled, { text = to_insert, w = w, h = h, x = cur_x, y = cur_y })
        else
          table.insert(compiled, { text = to_insert, w = w, h = h, x = cur_x, y = cur_y - h * fix_const })
          h = h - (h * fix_const)
        end

        cur_x = cur_x + w

        if total_height < h then
          total_height = h + Config.get('chatbox_message_margin')
        end
      end
    end
  end

  compiled.total_height = math.max(total_height, compiled.total_height)

  hook.run('ChatboxMessageCompiled', compiled)

  return compiled
end

function Chatbox.create()
  Chatbox.width = Theme.get_option('chatbox_width') or 100
  Chatbox.height = Theme.get_option('chatbox_height') or 100
  Chatbox.x = Theme.get_option('chatbox_x') or 0
  Chatbox.y = Theme.get_option('chatbox_y') or 0

  Chatbox.panel = vgui.Create('fl_chat_panel')
  Chatbox.panel:set_open(false)
end

function Chatbox.show()
  if !IsValid(Chatbox.panel) then
    if Theme.initialized() then
      Chatbox.create()
    else
      return
    end
  end

  Chatbox.panel:set_open(true)
end

function Chatbox.hide()
  if IsValid(Chatbox.panel) then
    Chatbox.panel:set_open(false)

    Chatbox.panel:SetMouseInputEnabled(false)
    Chatbox.panel:SetKeyboardInputEnabled(false)
  end
end

concommand.Add('fl_reset_chat', function()
  if IsValid(Chatbox.panel) then
    Chatbox.panel:safe_remove()
  end
end)
