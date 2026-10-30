--- RolePlay Commands turns the chat into roleplay chat.
-- Plain text is in character speech heard within the 'rp_commands_talk_radius' config. The text is written
-- in a small markup: `*text*` segments are actions and can be mixed with speech in one message,
-- `(text)` is a whisper and `text!!` a yell, and the amount of parentheses or exclamation marks
-- is the volume, which scales both the hearing radius and the font size. The `me`, `whisper`
-- and `yell` commands only wrap their text in that markup (see `RPCommands:wrap_speech`), and
-- `RPCommands:format_message` turns a phrase into a chat line on the server.
--
-- Besides speech the plugin adds out of character chat (`//` and `/ooc` for everyone, `.//`,
-- `[[` and `/looc` for the players nearby) with an OOC mute and cooldowns, the `it`, `its`,
-- `roll`, `event` and `eventlocal` commands, static texts, and the kinds of speech that the
-- Display Typing plugin shows above a typing player. The `roll` command rolls dice formulas
-- of the `Dice` library and the stats and skills of the Stats plugin, and
-- `RPCommands:announce_roll` shows any roll in the chat the way the command does.
--
-- Other plugins can step in through the `PlayerCanSayIC`, `PlayerCanUseOOC`,
-- `GetPlayerOOCName` and `AdjustPlayerRoll` hooks.
-- @module [RPCommands]

PLUGIN:set_global('RPCommands')

RPCommands.texts = RPCommands.texts or {}
RPCommands.speech_commands = {
  me = { '*', '*' },
  whisper = { '(', ')' },
  yell = { '', '!!' }
}
RPCommands.typing_kinds = {
  talking = { color = 'rp_commands_ic_color', volume = 0 },
  whispering = { color = 'rp_commands_whisper_color', volume = -1 },
  yelling = { color = 'rp_commands_yell_color', volume = 1 },
  performing = { color = 'rp_commands_me_color', volume = 0 }
}

--- Registers the permission that exempts a player from the OOC and LOOC cooldowns.
function RPCommands:RegisterPermissions()
  Bolt:register_permission('bypass_chat_cooldown', nil, nil, 'permission.categories.roleplay')
end

--- Wraps a text in the markup of a speech command, the way the command itself says it.
-- ```
-- RPCommands:wrap_speech('me', 'waves') -- '*waves*'
-- RPCommands:wrap_speech('whisper', 'over here') -- '(over here)'
-- RPCommands:wrap_speech('yell', 'run') -- 'run!!'
-- ```
-- @param id [String ID of the command: 'me', 'whisper' or 'yell']
-- @param text [String text given to the command]
-- @return [String the phrase to say, or the text as it is for any other command]
function RPCommands:wrap_speech(id, text)
  local markup = self.speech_commands[id]

  if !markup then
    return text
  end

  return markup[1]..text..markup[2]
end

--- Returns how far a phrase of a volume carries, compared to regular speech.
-- @param volume [Number volume from -3 to 3, as returned by `RPCommands:get_phrase_volume`]
-- @return [Number multiplier of the talk radius: 1 for regular speech, 0.6 to 0.2 for
--   whispers and 1.6 to 2.4 for yells]
function RPCommands:get_volume_range(volume)
  return volume == 0 ? 1 : (volume < 0 and (0.8 + volume * 0.2) or (1.2 + volume * 0.4))
end

--- Determines how loud a phrase is from its leading parentheses or trailing exclamation marks.
-- @param text [String phrase]
-- @return [String phrase without the parentheses, Number volume from -3 to 3]
function RPCommands:get_phrase_volume(text)
  local volume = 0

  if text:start_with('(') then
    local count = text:match('^([(]+)'):len()
    local end_count = (text:match('([)]+)$') or ''):len()

    volume -= count

    text = text:sub(count + 1, -end_count - 1)
  elseif text:end_with('!!') then
    volume = volume + text:match('([!]+)$'):len() - 1
  end

  volume = math.clamp(volume, -3, 3)

  text = text:strip()

  return text, volume
end

--- Registers the kinds of speech of the plugin with the Display Typing plugin, if it is
-- loaded, on both realms: the server reads the range of a kind to decide who is sent the
-- typing bubble, the client its label and color. Each kind is named by its
-- 'ui.hud.display_typing' phrase and has the range of its default volume;
-- `RPCommands:AdjustTypingDisplay` refines the color and the range for each text on the
-- client.
function RPCommands:PluginsLoaded()
  if !DisplayTyping or !isfunction(DisplayTyping.register_kind) then return end

  for id, data in pairs(self.typing_kinds) do
    DisplayTyping:register_kind(id, {
      name = 'ui.hud.display_typing.'..id,
      color = CLIENT and util.to_color(Config.get(data.color)) or nil,
      range = self:get_volume_range(data.volume)
    })
  end
end

require_relative 'sv_plugin'
require_relative 'sv_hooks'
require_relative 'cl_hooks'
