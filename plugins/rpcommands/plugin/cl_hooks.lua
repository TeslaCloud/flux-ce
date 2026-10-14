--- Client side of the RolePlay Commands plugin: draws the static texts, hides what players say
-- through the engine instead of the chatbox, and tells the Display Typing plugin what kind of
-- speech a player is typing (talking, whispering, yelling or performing), so that the typing
-- bubble is labelled, colored like the chat line the text will become, and seen as far as
-- that line will be heard.

local IsValid = IsValid
local isfunction = isfunction
local text_size = util.text_size

--- Checks whether a text starts with one of the given chat prefixes.
-- @param text [String lowercase text]
-- @param prefixes [List<String> lowercase prefixes]
-- @return [Boolean]
local function has_prefix(text, prefixes)
  for i = 1, #prefixes do
    if text:start_with(prefixes[i]) then
      return true
    end
  end

  return false
end

--- Checks whether a text is a radio message. The Radios plugin gives such a text a kind of
-- speech of its own, but it is loaded after this plugin, so its answer to the
-- DisplayTypingGetKind hook would never be asked for if this plugin claimed the text first.
-- @param text [String the text being typed, or its outline]
-- @return [Boolean false if the Radios plugin is not loaded]
local function is_radio_text(text)
  if !Communications or !isfunction(Communications.is_radio_text) then
    return false
  end

  return Communications.is_radio_text(text) == true
end

--- Draws nearby visible static texts, fading with distance and screen position. Staff holding Alt also see
-- who placed each text and when.
function RPCommands:HUDPaint()
  local client = PLAYER
  local texts = RPCommands.texts

  if !IsValid(client) or !next(texts) then return end

  local client_pos = EyePos()
  local scrw = ScrW()
  local cx, cy = ScrC()
  local font = Theme.get_font('menu_small')
  local show_author = input.IsKeyDown(KEY_LALT) and client:is_assistant()
  local offset = 4

  for k, v in pairs(texts) do
    local text_pos = v.pos

    if client_pos:DistToSqr(text_pos) <= 90000 and !util.vector_obstructed(client_pos, text_pos, client) then
      local pos = text_pos:ToScreen()
      local cam_mult = (1 - math.Distance(cx, cy, pos.x, pos.y) / scrw * 1.5)
      local distance_mult = (1 - client_pos:Distance(text_pos) / 300)
      local alpha = 255 * cam_mult * distance_mult
      local col1, col2 = Color(255, 255, 255, alpha), Color(0, 0, 0, alpha)
      local full_w, full_h = text_size(v.text, font)
      local lines = util.wrap_text(v.text, font, scrw * 0.25, cx - full_w * 0.5)

      if show_author then
        lines[#lines + 1] = v.name..' ('..v.steamid..')'
        lines[#lines + 1] = v.time
      end

      local cur_y = pos.y - ((full_h + offset) * #lines) * 0.5

      for i = 1, #lines do
        local line = lines[i]
        local w, h = text_size(line, font)

        draw.SimpleTextOutlined(line, font, pos.x - w * 0.5, cur_y, col1, nil, nil, 1, col2)

        cur_y = cur_y + h + offset
      end
    end
  end
end

--- Keeps what players say through the engine out of the chat. What is typed into the chatbox
-- reaches the server through the chatbox itself and comes back as a line of roleplay chat.
-- Plain text sent with the `say` console command does not: the base gamemode would show it
-- to every player on the server under the real name of the speaker, past the talk radius,
-- recognition and the speaking rules. Chat prefixes and commands in such a text are handled
-- by the server before it gets here, and the lines of the server console are added by the
-- Chatbox plugin.
-- @param speaker [Player the speaker, an invalid entity for the server console]
-- @param text [String the message]
-- @param team_chat [Boolean whether the message was sent to the team chat]
-- @param is_dead [Boolean whether the speaker is dead]
-- @return [Boolean true to hide what a player has said, nil for the server console]
function RPCommands:OnPlayerChat(speaker, text, team_chat, is_dead)
  if IsValid(speaker) then
    return true
  end
end

--- Keeps the colors of the registered kinds of speech in step with the chat colors, which
-- arrive from the server after the kinds have been registered.
-- @param key [String config key]
-- @param old_value [Any value the client had before]
-- @param new_value [Any value that has been received]
function RPCommands:OnConfigReceived(key, old_value, new_value)
  if !DisplayTyping or !isfunction(DisplayTyping.find_kind) then return end

  for id, data in pairs(self.typing_kinds) do
    local kind = data.color == key and DisplayTyping:find_kind(id)

    if kind then
      kind.color = self:get_chat_color(key)
    end
  end
end

--- Tells what kind of in character speech a text is going to be once it is sent, the same way
-- the server will read it: an action if the phrase starts with an asterisk, else a whisper or
-- a yell if it has a volume, else regular speech. The `me`, `whisper` and `yell` commands are
-- recognized by their exact names and aliases, so that `/w` does not match `/warn`. Works on
-- the outlines that the Display Typing plugin sends in place of a text as well, since they
-- keep the command and the punctuation at both ends.
-- @param text [String the text being typed, or its outline]
-- @return [String 'talking', 'whispering', 'yelling' or 'performing', Number volume of the
--   phrase from -3 to 3; nothing for out of character chat, for radio messages, for other
--   commands and for a text without a phrase]
function RPCommands:get_typing_kind(text)
  if !isstring(text) or !utf8.len(text) then return end

  local lower = text:lower()

  if has_prefix(lower, self.ooc_prefixes) or has_prefix(lower, self.looc_prefixes) then return end
  if is_radio_text(text) then return end

  local is_command, prefix_length = text:is_command()

  if is_command then
    local prefix = text:utf8sub(1, prefix_length)
    local name, arguments = text:match('^([%w_]+)(.*)$', #prefix + 1)
    local command = name and Flux.Command:find_by_id(name)

    if !command or !self.speech_commands[command.id] then return end
    if arguments != '' and !arguments:find('^%s') then return end

    text = self:wrap_speech(command.id, arguments:strip())
  else
    text = text:strip()
  end

  if text == '' then return end

  local phrase, volume = self:get_phrase_volume(text)

  if phrase:start_with('*') then
    return 'performing', volume
  elseif volume < 0 then
    return 'whispering', volume
  elseif volume > 0 then
    return 'yelling', volume
  end

  return 'talking', volume
end

--- Gives the typing bubble of a player the kind of speech they are typing: its label, the
-- color of the chat line it will become and the range that line will be heard from, which
-- follows the volume of the phrase. A knocked out player gets no bubble for in character
-- speech, which they cannot say.
-- @param target [Player player that is typing]
-- @param text [String text being typed, or its outline]
-- @return [Map/Boolean kind definition for the Display Typing plugin, false to show no bubble,
--   nil for anything that is not in character speech]
function RPCommands:DisplayTypingGetKind(target, text)
  local id, volume = self:get_typing_kind(text)

  if !id then return end

  if IsValid(target) and isfunction(target.is_knocked_out) and target:is_knocked_out() then
    return false
  end

  return {
    id = id,
    name = 'ui.hud.display_typing.'..id,
    color = self:get_chat_color(self.typing_kinds[id].color),
    range = self:get_volume_range(volume),
    live = true
  }
end

--- Returns the typing indicator text for emotes, whispers, yells and regular talking. Only
-- asked when `RPCommands:DisplayTypingGetKind` has not decided the kind of speech.
-- @param target [Player player that is typing]
-- @param text [String text being typed]
-- @return [String indicator text, nil for other commands]
function RPCommands:DisplayTypingTextType(target, text)
  local id = self:get_typing_kind(text)

  if id then
    return t('ui.hud.display_typing.'..id)
  end
end

--- Shrinks the typing indicator range for whispers and extends it for yells, by as much as
-- the volume of the phrase changes its hearing radius.
-- @param target [Player player that is typing]
-- @param text [String text being typed]
-- @return [Number multiplier of the squared range, nil for regular talking]
function RPCommands:DisplayTypingAdjustFadeoffMultiplier(target, text)
  local id, volume = self:get_typing_kind(text)

  if id and volume != 0 then
    local range = self:get_volume_range(volume)

    return range * range
  end
end

Cable.receive('fl_static_text_add', function(data)
  table.insert(RPCommands.texts, data)
end)

Cable.receive('fl_static_text_set', function(data)
  RPCommands.texts = data
end)

Cable.receive('fl_static_text_remove', function(id)
  table.remove(RPCommands.texts, id)
end)

Cable.receive('fl_notify_self', function(receiver, notification_color, message)
  chat.AddText(notification_color, message)
end)
