PLUGIN:set_global('Chatbox')

-- Enums for message data structures.
CHAT_ERROR  = -1
CHAT_NONE   = 0
CHAT_IMAGE  = 1
CHAT_LINK   = 2
CHAT_SIZE   = 3
CHAT_ITALIC = 4
CHAT_BOLD   = 5

util.include('cl_plugin.lua')
util.include('sv_plugin.lua')
util.include('cl_hooks.lua')
util.include('sv_hooks.lua')
