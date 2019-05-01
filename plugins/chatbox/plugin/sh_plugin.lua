PLUGIN:set_global('Chatbox')

-- Enums for message data structures.
CHAT_ERROR  = -1
CHAT_NONE   = 0
CHAT_IMAGE  = 1
CHAT_LINK   = 2
CHAT_SIZE   = 3
CHAT_ITALIC = 4
CHAT_BOLD   = 5

require_relative 'cl_plugin'
require_relative 'sv_plugin'
require_relative 'cl_hooks'
require_relative 'sv_hooks'
