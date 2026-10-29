--- Chat prefixes: texts such as `//` for out of character chat that a chat message can start
-- with to be handed to the plugin that has registered the prefix instead of being said in the
-- chat. A text that starts with a prefix is never a command, on the server and on the client
-- alike, so the registry exists on both realms and prefixes are registered in shared code;
-- their callbacks only run on the server (see `Chatbox.use_prefix`).

if !Chatbox then
  PLUGIN:set_global('Chatbox')
end

local string_lower = string.lower
local string_sub = string.sub

local prefixes = Chatbox.prefixes or {}
Chatbox.prefixes = prefixes

local longest = 0
local last_text, last_id, last_prefix

--- Remembers the length of the longest registered prefix, which is as much of a text as
-- `Chatbox.find_prefix` has to look at, and forgets the last text it has checked.
local function prefixes_changed()
  longest = 0
  last_text, last_id, last_prefix = nil, nil, nil

  for _, data in pairs(prefixes) do
    local list = data.prefix

    for i = 1, #list do
      longest = math.max(longest, #list[i])
    end
  end
end

prefixes_changed()

--- Registers a chat prefix, replacing any prefix with the same id. Call it on both realms:
-- the client needs the prefixes to tell them from commands, the server to hand the messages
-- that start with them to the callback.
-- ```
-- Chatbox.add_prefix('ooc', {
--   prefix = { '//', '/ooc ' },
--   callback = function(actor, message, team_chat)
--     RPCommands:say_ooc(actor, message, team_chat)
--   end
-- })
-- ```
-- @param id [String unique identifier of the prefix]
-- @param data [Map prefix (String or List<String> in lowercase) and callback (Function that
--   the server calls with the player, the message without the prefix and team_chat)]
function Chatbox.add_prefix(id, data)
  prefixes[id] = {
    prefix = istable(data.prefix) and data.prefix or { data.prefix },
    callback = data.callback
  }

  prefixes_changed()
end

--- Finds the registered chat prefix that a text starts with, ignoring the case of Latin
-- letters. If several prefixes match, the longest one is used. Only the start of the text,
-- as long as the longest prefix, is looked at, and the answer for the last text is kept, so
-- checking the same text again costs nothing.
-- @param text [String the text to check]
-- @return [String id of the prefix, String the prefix that matched; nothing if the text
--   starts with no prefix]
function Chatbox.find_prefix(text)
  if !isstring(text) then return end
  if text == last_text then return last_id, last_prefix end

  local head = string_lower(string_sub(text, 1, longest))
  local found_id, found_prefix

  for id, data in pairs(prefixes) do
    local list = data.prefix

    for i = 1, #list do
      local prefix = list[i]

      if (!found_prefix or #prefix > #found_prefix) and head:start_with(prefix) then
        found_id, found_prefix = id, prefix
      end
    end
  end

  last_text, last_id, last_prefix = text, found_id, found_prefix

  return found_id, found_prefix
end
