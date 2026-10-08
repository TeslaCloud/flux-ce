--- Prefixes lets plugins handle chat messages that start with a certain text, such as `//` for
-- out of character chat, without making them commands.
-- Register a prefix on the server with `Prefixes:add`: messages that start with it are handed
-- to its callback instead of the regular chat, and are never treated as commands. The
-- `PlayerUsedPrefix` hook is run after a prefix has handled a message.

PLUGIN:set_global('Prefixes')
PLUGIN:set_name('Prefixes')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds prefix adjusting to avoid troubles with certain commands.')

local stored = {}

--- Prevents text that starts with a registered prefix from being treated as a command.
-- @param text [String the text being checked]
-- @return [Boolean false if the text starts with a registered prefix, nil otherwise]
function Prefixes:StringIsCommand(text)
  for k, v in pairs(stored) do
    local prefix_table = istable(v.prefix) and v.prefix or { v.prefix }

    if table.reduce(prefix_table, function(a, prefix) return tobool(a) or text:start_with(prefix) end) then
      return false
    end
  end
end

if SERVER then
  --- Hands chat messages that start with a registered prefix (or pass its check function)
  -- over to that prefix instead of regular chat. Commands are left alone.
  -- @param actor [Player the speaker]
  -- @param text [String the message]
  -- @param team_chat [Boolean whether the message was sent to team chat]
  -- @return [String empty string to suppress the message if a prefix matched, nil otherwise]
  function Prefixes:PlayerSay(actor, text, team_chat)
    local lower_text = text:utf8lower()

    if !string.is_command(lower_text) then
      for k, v in pairs(stored) do
        local prefix_table = istable(v.prefix) and v.prefix or { v.prefix }

        for k2, v2 in pairs(prefix_table) do
          if lower_text:start_with(v2) or v.check and v.check(text) then
            return self:process_prefix(actor, k, v2, text, team_chat)
          end
        end
      end
    end
  end

  --- Strips the prefix from the message and passes the rest to the prefix's callback, then
  -- runs the PlayerUsedPrefix hook. Neither is run if nothing is left of the message.
  -- @param actor [Player the speaker]
  -- @param prefix_id [String id the prefix was registered with]
  -- @param prefix='' [String the prefix text that matched]
  -- @param text [String the full message]
  -- @param team_chat [Boolean whether the message was sent to team chat]
  -- @return [String always an empty string, which suppresses the original message]
  function Prefixes:process_prefix(actor, prefix_id, prefix, text, team_chat)
    prefix = prefix or ''

    local prefix_data = stored[prefix_id]
    local message = text:utf8sub((text:utf8lower():start_with(prefix) and utf8.len(prefix) or 0) + 1)

    if message != '' then
      prefix_data.callback(actor, message, team_chat)

      --- Called on the server after a chat message has been handled by the callback of a
      -- registered prefix.
      -- @param actor [Player The player who sent the message]
      -- @param prefix_id [String ID the prefix was registered with]
      -- @param message [String The message without the prefix]
      -- @param team_chat [Boolean Whether the message was sent to the team chat]
      hook.Run('PlayerUsedPrefix', actor, prefix_id, message, team_chat)
    end

    return ''
  end

  --- Registers a chat prefix, replacing any prefix with the same id. Serverside only.
  -- Messages that start with the prefix go to the callback instead of regular chat.
  -- ```
  -- Prefixes:add('ooc', {
  --   prefix = { '//', '((' },
  --   callback = function(actor, message, team_chat)
  --     -- message is the text with the prefix stripped
  --   end
  -- })
  -- ```
  -- @param id [String unique identifier of the prefix]
  -- @param data [Map prefix (lowercase String or List<String>), callback (Function that
  --   receives the player, the message without the prefix and team_chat) and optionally
  --   check (Function that receives the full text and returns true if it matches)]
  function Prefixes:add(id, data)
    stored[id] = data
  end
end
