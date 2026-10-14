--- Recognize gives every character a list of the characters it recognizes and the names it
-- knows them by.
-- A character is a stranger to everyone until they introduce themselves, under their real
-- name or a false one, to the player they look at or to everyone within whisper, talk or
-- yell range: from the menu on the ShowTeam key (F2 by default) or from the menu that
-- opens when another player is used. A player sees the name they know a character by on
-- the target ID, in in-character chat messages, on the scoreboard and in the typing bubbles;
-- strangers are shown as a stranger or by the start of their physical description. A
-- character can forget someone again from the menu that opens when that player is used or
-- from the menu of their scoreboard card, and staff make characters forget with the
-- CharForget and CharClearRecognition commands.
--
-- The `recog_enabled` config turns the whole system off, which makes everyone recognize
-- everyone. `recog_must_see` makes introductions need a clear line of sight, and
-- `recog_forget_on_death` and `recog_forgotten_on_death` decide what a death erases.
--
-- `Player:recognizes`, `Player:knows_real_name` and `Player:get_recognize` read the
-- recognitions on both realms; `Player:add_recognize`, `Player:remove_recognize` and
-- `Player:clear_recognizes` change them on the server. The `PlayerRecognizeTarget` hook
-- makes a player recognize another regardless of what is stored, and `PlayerCanRecognize`
-- and `PlayerCanForget` can refuse what players ask for.

PLUGIN:set_global('Recognizes')

--- The longest name a character can introduce themselves under, in characters. A schema
-- may change it.
Recognizes.max_name_length = Recognizes.max_name_length or 64

--- Checks whether the recognition system is on (the `recog_enabled` config). While it is
-- off everyone recognizes everyone and nobody can introduce themselves or forget anyone;
-- the stored recognitions are kept.
-- @return [Boolean]
function Recognizes:is_enabled()
  return Config.get('recog_enabled') != false
end

--- Returns what a player is called by those who do not recognize them: the start of
-- their physical description in square brackets.
-- @param target [Player]
-- @return [String]
function Recognizes:get_unrecognized_name(target)
  local description = ''

  if CLIENT or target:get_character() then
    description = target:get_phys_desc()
  end

  return '['..description:utf8sub(1, 32)..'...]'
end

--- Returns the name a player knows another player by, or what strangers are called if
-- they do not recognize them. On the client only the recognitions of the local player
-- are meaningful.
-- @param viewer [Player player whose knowledge is asked about]
-- @param target [Player player to name]
-- @return [String the name, nil if the target is not a valid player]
-- @see [Recognizes#get_unrecognized_name]
function Recognizes:get_known_name(viewer, target)
  local is_known, known_name = viewer:recognizes(target)

  if is_known then
    return known_name
  end

  return self:get_unrecognized_name(target)
end

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
