--- The kind of in character speech that a text being typed is going to be, which the client
-- hooks of the RolePlay Commands plugin tell the Display Typing plugin.

if !RPCommands then
  PLUGIN:set_global('RPCommands')
end

--- Tells what kind of in character speech a text is going to be once it is sent, the same way
-- the server will read it: an action if the phrase starts with an asterisk, else a whisper or
-- a yell if it has a volume, else regular speech. The `me`, `whisper` and `yell` commands are
-- recognized by their exact names and aliases, so that `/w` does not match `/warn`. Works on
-- the outlines that the Display Typing plugin sends in place of a text as well, since they
-- keep the command and the punctuation at both ends.
-- @param text [String the text being typed, or its outline]
-- @return [String 'talking', 'whispering', 'yelling' or 'performing', Number volume of the
--   phrase from -3 to 3; nothing for a text that starts with a chat prefix (out of
--   character chat, radio messages), for other commands and for a text without a phrase]
function RPCommands:get_typing_kind(text)
  if !isstring(text) or !utf8.len(text) then return end

  local is_command, prefix_length = Flux.Command:is_command(text)

  if is_command then
    local prefix = text:utf8sub(1, prefix_length)
    local name, arguments = text:match('^([%w_]+)(.*)$', #prefix + 1)
    local command = name and Flux.Command:find_by_id(name)

    if !command or !self.speech_commands[command.id] then return end
    if arguments != '' and !arguments:find('^%s') then return end

    text = self:wrap_speech(command.id, arguments:strip())
  elseif Chatbox.find_prefix(text) then
    return
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
