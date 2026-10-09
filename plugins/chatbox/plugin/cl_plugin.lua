--- Client side of the Chatbox plugin, which takes over the `chat.AddText` function of GMod.
-- Text added with `chat.AddText` is sent to the server and comes back as a chatbox message for
-- the local player; the original function is kept in Chatbox.old_add_text. The rest of this
-- file adds received messages to the chatbox (`Chatbox.add_message`), compiles them into
-- pieces that can be drawn (`Chatbox.compile`) and creates, shows and hides the chatbox panel.
-- @module [chat]

Chatbox.width = Chatbox.width or 100
Chatbox.height = Chatbox.height or 100
Chatbox.x = Chatbox.x or 0
Chatbox.y = Chatbox.y or 0

Chatbox.old_add_text = Chatbox.old_add_text or chat.AddText

--- Replaces the default chat.AddText. The arguments are sent to the server, which
-- sends them back to the local player as a chatbox message.
-- @param ... [Vararg strings, colors, font sizes, players and entities to display]
function chat.AddText(...)
  Cable.send('fl_chat_text_add', ...)
end

--- Adds a message to the chatbox of the local player and plays the chat sound, creating the
-- chatbox panel first if necessary. This is what happens to every message that arrives from
-- the server; call it directly to show a message that only exists on this client.
-- Does nothing if there is no panel and the theme has not been initialized yet.
-- Clientside only.
-- ```
-- Chatbox.add_message({ data = { Color(255, 200, 0), 'Only you can see this.' } })
-- ```
-- @param message_data [Map message data: data (List of strings, font sizes, colors, image,
--   icon and avatar tables, players and entities), optional size, time and should_translate]
-- @see [Chatbox.compile]
function Chatbox.add_message(message_data)
  if !IsValid(Chatbox.panel) then
    if Theme.initialized() then
      Chatbox.create()
    else
      return
    end
  end

  Chatbox.panel:add_message(message_data)

  chat.PlaySound()
end

--- Converts a message that was received from the server into a list of pieces with
-- calculated sizes and positions, ready to be drawn by a fl_chat_message panel.
-- Strings are wrapped to the width of the chatbox. While the 'chat_timestamps' config is
-- enabled the message starts with the time it was sent at. Clientside only.
-- @param msg_table [Map message data: data (List of strings, font sizes, colors,
--   image / icon / avatar tables, players and entities), optional size, time (os.time() of
--   the message, the current time when omitted) and should_translate]
-- @return [Map sequential pieces: font sizes (Number), colors (Color), texts
--   ({ text, w, h, x, y }), images ({ image or icon, x, y, w, h }) and avatars
--   ({ avatar, x, y, w, h }), plus the total_height field; nil if the chatbox font is not
--   available]
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

  --- Lets plugins compile a whole message themselves. Called on the client by
  -- `Chatbox.compile` before the pieces of the message are compiled; gamemode hooks are not
  -- called.
  -- @param data [List pieces of the message as they were received from the server]
  -- @param compiled [Map compiled message to fill in; it already holds the initial font size,
  --   and its total_height field should be set to the height of the message]
  -- @return [Boolean return true to skip the default compilation of all pieces]
  if Plugin.call('ChatboxCompileMessage', data, compiled) != true then
    if Config.get('chat_timestamps') then
      local stamp = os.date('%H:%M', isnumber(msg_table.time) and msg_table.time or os.time())..' '
      local w, h = util.text_size(stamp, font)

      table.insert(compiled, Theme.get_color('chat_timestamp', Color(170, 170, 170)))

      if !fix then
        table.insert(compiled, { text = stamp, w = w, h = h, x = cur_x, y = cur_y })
      else
        table.insert(compiled, { text = stamp, w = w, h = h, x = cur_x, y = cur_y - h * fix_const })
        h = h - (h * fix_const)
      end

      table.insert(compiled, Color(255, 255, 255))

      cur_x = cur_x + w
      total_height = h + Config.get('message_margin')
    end

    for k, v in ipairs(data) do
      --- Lets plugins compile a single piece of a message. Called on the client for every
      -- piece in order, unless ChatboxCompileMessage has taken over the whole message;
      -- gamemode hooks are not called.
      -- @param piece [Any a string, font size, color, icon, image or avatar table, player or
      --   entity]
      -- @param compiled [Map the message compiled so far, to append to]
      -- @return [Boolean return true to skip the default handling of this piece]
      if Plugin.call('ChatboxCompileMessageData', v, compiled) == true then
        continue
      end

      if isstring(v) then
        if should_translate then
          data[k] = t(v)
        end

        local wrapped =
          util.wrap_text(v, font, Chatbox.width - Theme.get_option('chatbox_padding', math.scale(8)) * 4, cur_x)
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

          if total_height < h then
            total_height = h + Config.get('message_margin')
          end

          if line_count > 1 and k2 != line_count then
            cur_y = cur_y + h + Config.get('message_margin')

            total_height = total_height + h + Config.get('message_margin')

            cur_x = 0
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
            total_height = scaled + Config.get('message_margin')
          end
        elseif v.avatar then
          local _, line_height = util.text_size('W', font)

          if fix then
            line_height = line_height - line_height * fix_const
          end

          local size = math.floor(isnumber(v.size) and math.scale(v.size) or line_height)
          local margin = math.scale(isnumber(v.margin) and v.margin or 8)
          local wrap_width = Chatbox.width - Theme.get_option('chatbox_padding', math.scale(8)) * 4

          if cur_x > 1 and cur_x + size + margin > wrap_width then
            cur_x = 0
            cur_y = cur_y + line_height + Config.get('message_margin')
          end

          table.insert(compiled, {
            avatar  = v.avatar,
            x       = cur_x + math.ceil(margin * 0.5),
            y       = cur_y + math.max(0, math.floor((line_height - size) * 0.5)),
            w       = size,
            h       = size
          })

          cur_x = cur_x + size + margin
          total_height = math.max(total_height, cur_y + size + Config.get('message_margin'))
        elseif v.r and v.g and v.b and v.a then
          table.insert(compiled, Color(v.r, v.g, v.b, v.a))
        end
      elseif IsValid(v) then
        local to_insert = ''

        if v:IsPlayer() then
          to_insert =
            --- Decides whether the name of a player in a message goes through the
            -- GetPlayerName hook. Called on the client by `Chatbox.compile` for every
            -- player that is part of a message.
            -- @param target [Player the player whose name is displayed]
            -- @param message_data [Map message data received from the server]
            -- @return [Boolean return false to display the true name of the player]
            hook.Run('ShouldProcessPlayerName', v, msg_table) != false and hook.Run('GetPlayerName', v) or v:name(true)
        else
          to_insert = tostring(v)
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
          total_height = h + Config.get('message_margin')
        end
      end
    end
  end

  compiled.total_height = math.max(total_height, compiled.total_height)

  --- Called on the client when a message has been compiled, before `Chatbox.compile` returns
  -- it. The Chatbox plugin itself uses it to print the message to the console.
  -- @param compiled [Map the compiled message; changes made to it are kept]
  hook.Run('ChatboxMessageCompiled', compiled)

  return compiled
end

--- Creates the chatbox panel in its closed state, taking the size and position
-- from the current theme. The panel is stored in Chatbox.panel.
function Chatbox.create()
  Chatbox.width = Theme.get_option('chatbox_width') or 100
  Chatbox.height = Theme.get_option('chatbox_height') or 100
  Chatbox.x = Theme.get_option('chatbox_x') or 0
  Chatbox.y = Theme.get_option('chatbox_y') or 0

  Chatbox.panel = vgui.Create('fl_chat_panel')
  Chatbox.panel:set_open(false)
end

--- Opens the chatbox, creating its panel first if necessary.
-- Does nothing if there is no panel and the theme has not been initialized yet.
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

--- Closes the chatbox, disables its mouse and keyboard input and runs the
-- ChatTextChanged hook with an empty string.
function Chatbox.hide()
  if IsValid(Chatbox.panel) then
    Chatbox.panel:set_open(false)

    Chatbox.panel:SetMouseInputEnabled(false)
    Chatbox.panel:SetKeyboardInputEnabled(false)

    hook.Run('ChatTextChanged', '')
  end
end

concommand.Add('fl_reset_chat', function()
  if IsValid(Chatbox.panel) then
    Chatbox.panel:safe_remove()
  end
end)
