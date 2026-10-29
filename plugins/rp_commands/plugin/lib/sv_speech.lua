--- The pipeline that turns a typed phrase into a line of in character chat:
-- `RPCommands:get_phrase_volume` (shared, in sh_plugin.lua) reads how loud the phrase is,
-- `RPCommands:get_phrase_table` splits it into speech and actions, and
-- `RPCommands:format_message` puts the chat line together. The talk radius is the
-- 'rp_commands_talk_radius' config and the chat colors are the 'rp_commands_*_color' configs.

if !RPCommands then
  PLUGIN:set_global('RPCommands')
end

local config_get = Config.get

--- Splits a phrase into alternating speech and asterisk emote parts with quotes and colors.
-- @param text [String phrase]
-- @return [Table chat message parts]
function RPCommands:get_phrase_table(text)
  local msg_table = {}
  local is_emote = text:start_with('*')
  local text_parts = {}
  local pieces = text:split('*')
  local count = 0

  for i = 1, #pieces do
    local piece = pieces[i]

    if piece != '' and piece:match('%S') then
      count += 1
      text_parts[count] = piece
    end
  end

  local ic_color = config_get('rp_commands_ic_color')
  local me_color = config_get('rp_commands_me_color')
  local length = 0

  if !is_emote then
    length = 1
    msg_table[1] = '"'
  end

  for k = 1, count do
    if k != 1 then
      if !is_emote then
        length += 1
        msg_table[length] = ic_color
      end

      length += 1
      msg_table[length] = is_emote ? '" ' : ' "'
    end

    local part = text_parts[k]:strip()

    if is_emote then
      length += 1
      msg_table[length] = me_color

      if part:is_upper() then
        part = part:utf8lower()
      end
    end

    if k == 1 or k == count then
      part = part:spelling(is_emote, k == 1 and count != 1)
    end

    length += 1
    msg_table[length] = part

    is_emote = !is_emote
  end

  if is_emote then
    msg_table[length + 1] = '"'
  end

  return msg_table
end

--- Formats an in character message, scaling its font size, verb and hearing radius by the phrase volume.
-- @param speaker [Player player speaking]
-- @param text [String phrase]
-- @return [Table chat message parts ending with the message data]
function RPCommands:format_message(speaker, text)
  local phrase, volume = self:get_phrase_volume(text)
  local is_emote = phrase:start_with('*')
  local color = config_get(is_emote ? 'rp_commands_me_color' : 'rp_commands_ic_color')

  local msg_table = {
    color,
    config_get('chatbox_default_font_size') + volume * 2,
    speaker, ' '
  }

  if !is_emote then
    msg_table[5] = volume == 0 and t'ui.chat.say' or (volume < 0 and t'ui.chat.whisper' or t'ui.chat.yell')
    msg_table[6] = ': '

    if volume == 3 then
      phrase = phrase:utf8upper()
    end
  else
    if volume > 0 then
      phrase = phrase:sub(1, -phrase:match('([!]+)$'):len() - 1)
    end
  end

  table.Add(msg_table, self:get_phrase_table(phrase))

  table.insert(msg_table, {
    sender = speaker,
    position = speaker:EyePos(),
    radius = config_get('rp_commands_talk_radius') * self:get_volume_range(volume),
    ic = true
  })

  return msg_table
end
