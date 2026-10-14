--- Radios lets characters talk to each other over any distance.
-- A radio is an item with a frequency. A character who keeps an enabled radio in their
-- hotbar speaks on its frequency by starting a chat message with one of
-- `Communications.prefixes`, and everyone with an enabled radio tuned to that frequency in
-- their own hotbar receives the message wherever they are. The players standing near the
-- speaker overhear it, like anything else that is said out loud.
--
-- The frequency of a radio is changed through its item menu: the server asks the player
-- for the new frequency with a prompt and checks the answer before the radio is retuned.
--
-- Three server-side hooks surround a transmission: `PlayerCanRadio` can forbid a player to
-- speak on the radio, `PlayerAdjustRadioInfo` decides who receives the message and
-- `PlayerRadioUsed` is run once it has been sent. If the Display Typing plugin is loaded,
-- players who are typing a radio message are shown as 'radioing'.
-- @module [Communications]

PLUGIN:set_global 'Communications'

Communications.prefixes = { '/r ', '/radio', ';' }
Communications.typing_color = Color(100, 228, 100)
Communications.typing_range = 0.5

--- Checks whether a chat text is a radio message, that is whether it starts with one of
-- `Communications.prefixes`. Letter case is ignored, as it is when the message is sent.
-- @param text [String chat text, or its outline made by the Display Typing plugin]
-- @return [Boolean]
function Communications.is_radio_text(text)
  if !isstring(text) then return false end

  local lower_text = text:utf8lower()
  local prefixes = Communications.prefixes

  for i = 1, #prefixes do
    if lower_text:start_with(prefixes[i]) then
      return true
    end
  end

  return false
end

--- Turns what a player has typed into a radio frequency. A frequency is written as three
-- digits, a decimal point and one more digit, such as '100.1'; a comma is accepted in place
-- of the point and the spaces around the text are ignored.
-- @param value [String text to parse]
-- @return [Number the frequency, or nil if the text is not a valid frequency]
function Communications.parse_frequency(value)
  if !isstring(value) then return end

  local whole, tenths = value:strip():match('^(%d%d%d)[%.,](%d)$')

  if !whole then return end

  return (tonumber(whole) * 10 + tonumber(tenths)) / 10
end

--- Writes a radio frequency the way players enter it: three digits, a decimal point and
-- one more digit.
-- @param frequency [Number]
-- @return [String for example '100.1', or an empty string if the frequency is not a number]
function Communications.format_frequency(frequency)
  if !isnumber(frequency) then return '' end

  return string.format('%05.1f', frequency)
end

--- Registers the 'radioing' kind of speech with the Display Typing plugin, if it is loaded.
-- The bubble of a player who is typing a radio message is visible from as far away as the
-- message itself is overheard.
function Communications:OnPluginsLoaded()
  if !DisplayTyping then return end

  DisplayTyping:register_kind('radioing', {
    name = 'ui.hud.display_typing.radioing',
    color = self.typing_color,
    range = self.typing_range
  })
end

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
