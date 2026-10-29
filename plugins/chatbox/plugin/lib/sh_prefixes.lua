--- Chat prefixes: texts such as `//` for out of character chat that a chat message can start
-- with to be handed to the plugin that has registered the prefix instead of being said in the
-- chat. A text that starts with a prefix is never a command, on the server and on the client
-- alike, so the registry exists on both realms and prefixes are registered in shared code;
-- their callbacks only run on the server (see `Chatbox.use_prefix`).

if !Chatbox then
  PLUGIN:set_global('Chatbox')
end

local prefixes = Chatbox.prefixes or {}
Chatbox.prefixes = prefixes

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
-- @param data [Map prefix (lowercase String or List<String>) and callback (Function that the
--   server calls with the player, the message without the prefix and team_chat)]
function Chatbox.add_prefix(id, data)
  prefixes[id] = {
    prefix = istable(data.prefix) and data.prefix or { data.prefix },
    callback = data.callback
  }
end

--- Finds the registered chat prefix that a text starts with, ignoring letter case. If several
-- prefixes match, the longest one is used.
-- @param text [String the text to check]
-- @return [String id of the prefix, String the prefix that matched; nothing if the text
--   starts with no prefix]
function Chatbox.find_prefix(text)
  if !isstring(text) then return end

  local lower_text = text:utf8lower()
  local found_id, found_prefix

  for id, data in pairs(prefixes) do
    local list = data.prefix

    for i = 1, #list do
      local prefix = list[i]

      if (!found_prefix or #prefix > #found_prefix) and lower_text:start_with(prefix) then
        found_id, found_prefix = id, prefix
      end
    end
  end

  return found_id, found_prefix
end
