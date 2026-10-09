--- Chatbox replaces the default chat of the game with the chat of Flux.
-- Every message goes through the server. `Chatbox.add_text` builds a message out of strings,
-- colors, font sizes, icons, avatars, players and entities and sends it to the players who can
-- hear it, and `Chatbox.player_say` does the same for what a player has typed. On the client a
-- message is compiled into pieces that can be drawn (`Chatbox.compile`) and added to the
-- chatbox panel, which also lists the matching commands while one is being typed.
-- `chat.AddText` is redirected to the chatbox too, and what is typed with `say` in the server
-- console is shown as a line of the console.
--
-- Plugins shape the chat through hooks: `PlayerSay` and `ChatboxAdjustPlayerSay` change what a
-- player says, `ChatboxGetPlayerIcon`, `ChatboxGetPlayerColor` and `ChatboxGetMessageColor`
-- style it, `ChatboxShouldSendMessage` can cancel a message, `AdjustMessageData` and
-- `PlayerCanHear` decide who receives it, `ChatboxMessageSent` tells who has received it, and
-- `ChatboxCompileMessage`, `ChatboxShouldAddMessage` and `ChatboxPrePaintMessage` take over
-- how it is displayed. Font sizes, the message limit, the fade delay, the length of a message,
-- the interval between two messages of a player, avatars and timestamps are set through the
-- config keys of the chatbox category.
-- @module [Chatbox]

PLUGIN:set_global('Chatbox')

--- Returns a message piece that displays the Steam avatar of a player in a chat message.
-- Pass the piece to `Chatbox.add_text` (or to `chat.AddText` on the client) at the place of
-- the message where the avatar should be. The piece holds the SteamID64 rather than the
-- player, so the avatar stays in the chat history after the player has left.
-- ```
-- -- The avatar of the speaker before their name.
-- Chatbox.add_text(nil, Chatbox.avatar(actor), team.GetColor(actor:Team()), actor,
--   Color(255, 255, 255), ': ', text, { sender = actor })
--
-- -- Only when the server has avatars enabled; an empty table adds nothing to a message.
-- Chatbox.add_text(nil, Config.get('chat_avatars') and Chatbox.avatar(actor) or {}, actor, ': ', text)
-- ```
-- @param target [Player/String the player, or a SteamID64]
-- @param size=nil [Number width and height of the avatar before screen scaling; the height
--   of a line of text at that place of the message when omitted]
-- @param margin=8 [Number horizontal space around the avatar before screen scaling, half of
--   it on each side]
-- @return [Map avatar piece: avatar (String SteamID64), size, margin and is_data = true; the
--   piece displays nothing if the target is neither a player nor a string]
function Chatbox.avatar(target, size, margin)
  local steam_id = target

  if !isstring(target) then
    steam_id = isentity(target) and IsValid(target) and target:IsPlayer() and target:SteamID64() or nil
  end

  return { avatar = steam_id, size = size, margin = margin, is_data = true }
end

require_relative 'cl_plugin'
require_relative 'sv_plugin'
require_relative 'cl_hooks'
require_relative 'sv_hooks'
