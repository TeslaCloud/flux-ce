--- Chatbox replaces the default chat of the game with the chat of Flux.
-- Every message goes through the server. `Chatbox.add_text` builds a message out of strings,
-- colors, font sizes, icons, players and entities and sends it to the players who can hear it,
-- and `Chatbox.player_say` does the same for what a player has typed. On the client a message
-- is compiled into pieces that can be drawn (`Chatbox.compile`) and added to the chatbox
-- panel, which also lists the matching commands while one is being typed. `chat.AddText` is
-- redirected to the chatbox too.
--
-- Plugins shape the chat through hooks: `PlayerSay` and `ChatboxAdjustPlayerSay` change what a
-- player says, `ChatboxGetPlayerIcon`, `ChatboxGetPlayerColor` and `ChatboxGetMessageColor`
-- style it, `AdjustMessageData` and `PlayerCanHear` decide who receives a message, and
-- `ChatboxCompileMessage`, `ChatboxShouldAddMessage` and `ChatboxPrePaintMessage` take over
-- how it is displayed. Font sizes, the message limit and the fade delay are set through the
-- config keys of the chatbox category.
-- @module [Chatbox]

PLUGIN:set_global('Chatbox')

require_relative 'cl_plugin'
require_relative 'sv_plugin'
require_relative 'cl_hooks'
require_relative 'sv_hooks'
