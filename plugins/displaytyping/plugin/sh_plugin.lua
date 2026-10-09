--- Display Typing shows players a bubble for everyone nearby who is typing in the chatbox.
-- The bubble names the typing player, says what kind of speech they are typing (talking,
-- whispering and so on) and, if the server and the viewer allow it, shows the text as it is
-- being typed. It sits above the head of a player who is in view and is held at the edge of the
-- screen, with a pointer towards the player, for one who is off screen or behind the viewer.
--
-- The client of a typing player reports the text to the server a few times a second, and the
-- server passes it on only to the players who are near enough to see the bubble; players who
-- are dead, hidden or in observer mode are not shown as typing at all. When the
-- 'display_exact_message' config is disabled, or the text is a command that no plugin has
-- claimed as speech, the text itself never leaves the client: only its outline is sent (see
-- `DisplayTyping:outline`), which is enough for hooks to tell the kind of speech.
--
-- The kind of speech is decided on the client by the `DisplayTypingGetKind` hook, which
-- returns the ID of a kind registered with `DisplayTyping:register_kind`. The older
-- `DisplayTypingTextType` and `DisplayTypingAdjustFadeoffMultiplier` hooks keep working for
-- plugins that only provide a label and a range. Each player can turn the bubbles or the live
-- text off in the client settings, if the Settings plugin is loaded.
-- @module [DisplayTyping]

PLUGIN:set_global('DisplayTyping')

DisplayTyping.kinds = DisplayTyping.kinds or {}
DisplayTyping.placeholder = '…'
DisplayTyping.max_range = 4

local head_limit = 32
local punctuation_limit = 8

--- Registers a kind of speech that a typing bubble can show. A kind gives the bubble its
-- label and color and scales the distance it is visible from.
-- ```
-- DisplayTyping:register_kind('whispering', {
--   name = 'ui.hud.display_typing.whispering',
--   color = Color(150, 170, 200),
--   range = 0.25
-- })
--
-- function MyPlugin:DisplayTypingGetKind(target, text)
--   if text:start_with('/w ') then
--     return 'whispering'
--   end
-- end
-- ```
-- @param id [String unique ID of the kind]
-- @param data [Map kind definition, all fields optional: name (String phrase or text of the
--   label, the 'typing' label by default), color (Color of the label and the animated dots,
--   the accent color of the bubble by default), range (Number multiplier of the
--   'display_typing_range' config for this kind, 1 by default), live (Boolean whether the text
--   may be shown as it is typed, true by default)]
-- @return [Map the registered kind, or nil if the arguments are not valid]
function DisplayTyping:register_kind(id, data)
  if !isstring(id) or !istable(data) then return end

  data.id = id
  data.name = data.name or 'ui.hud.display_typing.typing'
  data.range = tonumber(data.range) or 1
  data.live = data.live != false

  self.kinds[id] = data

  return data
end

--- Returns a registered kind of speech.
-- @param id [String ID of the kind]
-- @return [Map kind definition, or nil if it is not registered]
function DisplayTyping:find_kind(id)
  return self.kinds[id]
end

--- Returns the distance within which the bubble of a typing player is visible, before the
-- kind of speech scales it.
-- @return [Number distance in units, the 'display_typing_range' config]
function DisplayTyping:get_range()
  return tonumber(Config.get('display_typing_range')) or 350
end

--- Checks whether the server lets players see the text that others are typing.
-- @return [Boolean false if the 'display_exact_message' config is disabled]
function DisplayTyping:live_text_allowed()
  return Config.get('display_exact_message') != false
end

--- Returns the ragdoll that stands in for a player who has fallen over, if the Ragdoll plugin
-- is loaded.
-- @param target [Player]
-- @return [Entity the ragdoll, or nil if the player has none]
function DisplayTyping:get_ragdoll(target)
  if !ENT_RAGDOLL then return end

  local ragdoll = target:GetDTEntity(ENT_RAGDOLL)

  if IsValid(ragdoll) and ragdoll:IsRagdoll() then
    return ragdoll
  end
end

--- Reduces a text to its outline: what it starts and ends with, without anything it says.
-- The outline keeps the command at the start of the text (the command prefix and the name
-- made of Latin letters, digits and underscores) or else the punctuation it starts with, and
-- the punctuation it ends with; everything in between is replaced with a single ellipsis
-- (`DisplayTyping.placeholder`). It is what other players receive in place of a text they
-- are not allowed to see, so that the hooks that tell the kind of speech by a prefix or an
-- ending still work. The outline of an outline is the same outline.
-- ```
-- DisplayTyping:outline('/me waves his hand.') -- '/me ….'
-- DisplayTyping:outline('(over here') -- '(…'
-- DisplayTyping:outline('Watch out!!') -- '…!!'
-- DisplayTyping:outline('Hello there') -- '…'
-- ```
-- @param text [String text to reduce]
-- @return [String the outline; an empty string for an empty text, the placeholder alone
--   for a text that is not valid UTF-8]
function DisplayTyping:outline(text)
  if !isstring(text) or text == '' then return '' end
  if !utf8.len(text) then return self.placeholder end

  local head = ''
  local consumed = 0
  local is_command, prefix_length = text:is_command()

  if is_command then
    local prefix = text:utf8sub(1, prefix_length)
    local name = text:match('^[%w_]+', #prefix + 1)

    if name then
      head = prefix..name:sub(1, head_limit)
      consumed = #prefix + #name
    else
      local marks = text:match('^%p+', #prefix + 1) or ''

      head = prefix..marks:sub(1, punctuation_limit)
      consumed = #prefix + #marks
    end
  else
    local marks = text:match('^%p+') or ''

    head = marks:sub(1, punctuation_limit)
    consumed = #marks
  end

  local rest = text:sub(consumed + 1)
  local tail = rest:match('%p+$') or ''
  local body = rest:sub(1, #rest - #tail)

  tail = tail:sub(-punctuation_limit)

  if !body:find('%S') then
    return head..tail
  end

  return head..(body:find('^%s') and ' ' or '')..self.placeholder..tail
end

--- Decides whether the live text setting is listed in the settings menu: only while the
-- player has typing bubbles turned on and the server allows live text.
-- @param setting [Map definition of the setting]
-- @return [Boolean]
local function live_text_setting_visible(setting)
  return ClientSettings:get('display_typing_bubbles') and DisplayTyping:live_text_allowed()
end

--- Registers the client settings of the plugin: whether the player sees typing bubbles at
-- all, which the server is told so that it does not send them anything, and whether the
-- bubbles show the text as it is typed. Only called if the Settings plugin is loaded.
function DisplayTyping:RegisterClientSettings()
  ClientSettings:register_setting('display_typing_bubbles', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.chat',
    name = 'settings.display_typing.bubbles.name',
    description = 'settings.display_typing.bubbles.desc',
    networked = true
  })

  ClientSettings:register_setting('display_typing_live_text', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.chat',
    name = 'settings.display_typing.live_text.name',
    description = 'settings.display_typing.live_text.desc',
    visible = live_text_setting_visible
  })
end

DisplayTyping:register_kind('typing', {
  name = 'ui.hud.display_typing.typing'
})

require_relative 'cl_plugin'
require_relative 'cl_bubbles'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
