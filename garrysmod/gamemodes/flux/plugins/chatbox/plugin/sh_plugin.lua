--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

PLUGIN:SetAlias("flChatbox")

library.New "chatbox"

-- Enums for message data structures.
CHAT_NONE = 0
CHAT_IMAGE = 1
CHAT_LINK = 2
CHAT_SIZE = 3
CHAT_ITALIC = 4
CHAT_BOLD = 5
CHAT_ERROR = 999

util.Include("cl_plugin.lua")
util.Include("sv_plugin.lua")
util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")
