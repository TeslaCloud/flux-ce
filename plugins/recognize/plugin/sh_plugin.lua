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
--
-- The plugin also keeps the completion of player arguments of commands from giving names
-- away: players without the 'staff' permission are only offered the real names of the
-- characters they know by that name and of their own (see `Recognizes.complete_player`).

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

if Flux.Command:get_completer('player') != Recognizes.complete_player then
  Recognizes.base_player_completer = Flux.Command:get_completer('player')
end

--- Completes arguments of the 'player' type, wrapping the completer that was registered for
-- that type before. Staff and the server console get all of its suggestions. Other players
-- are not offered the real name of a character they do not know by that name: they get the
-- names of their own character and of the characters they know by their real names, along
-- with Steam names and SteamIDs; the Steam name of a character they do not know is offered
-- whenever it contains the typed text.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments typed before it]
-- @param cmd [Command the command or subcommand the argument belongs to]
-- @return [List<String> the names to suggest]
function Recognizes.complete_player(actor, partial, args, cmd)
  local base = Recognizes.base_player_completer
  local values = isfunction(base) and base(actor, partial, args, cmd) or {}

  if !IsValid(actor) or actor:can('staff') then
    return values
  end

  local lower = isstring(partial) and partial:utf8lower() or ''
  local hidden, shown, steam_names = {}, {}, {}

  for _, client in player.Iterator() do
    local char_name = client:name(true)
    local steam_name = client:steam_name()

    if client == actor or actor:knows_real_name(client) then
      shown[char_name] = true
    else
      hidden[char_name] = true

      if lower != '' and steam_name:utf8lower():find(lower, 1, true) then
        steam_names[#steam_names + 1] = steam_name
      end
    end

    shown[steam_name] = true
  end

  local allowed, seen = {}, {}

  for _, value in ipairs(values) do
    if shown[value] or !hidden[value] then
      allowed[#allowed + 1] = value
      seen[value] = true
    end
  end

  for _, steam_name in ipairs(steam_names) do
    if !seen[steam_name] then
      allowed[#allowed + 1] = steam_name
      seen[steam_name] = true
    end
  end

  return allowed
end

Flux.Command:add_completer('player', Recognizes.complete_player)

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
