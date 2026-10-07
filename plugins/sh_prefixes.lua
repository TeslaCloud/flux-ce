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

    if table.reduce(prefix_table, function(a, prefix) return tobool(a) or text:starts(prefix) end) then
      return false
    end
  end
end

if SERVER then
  --- Hands chat messages that start with a registered prefix (or pass its check function)
  -- over to that prefix instead of regular chat. Commands are left alone.
  -- @param player [Player the speaker]
  -- @param text [String the message]
  -- @param team_chat [Boolean whether the message was sent to team chat]
  -- @return [String empty string to suppress the message if a prefix matched, nil otherwise]
  function Prefixes:PlayerSay(player, text, team_chat)
    local lower_text = text:utf8lower()

    if !string.is_command(lower_text) then
      for k, v in pairs(stored) do
        local prefix_table = istable(v.prefix) and v.prefix or { v.prefix }

        for k2, v2 in pairs(prefix_table) do
          if lower_text:starts(v2) or v.check and v.check(text) then
            return self:process_prefix(player, k, v2, text, team_chat)
          end
        end
      end
    end
  end

  --- Strips the prefix from the message and passes the rest to the prefix's callback, then
  -- runs the PlayerUsedPrefix hook. Neither is run if nothing is left of the message.
  -- @param player [Player the speaker]
  -- @param prefix_id [String id the prefix was registered with]
  -- @param prefix='' [String the prefix text that matched]
  -- @param text [String the full message]
  -- @param team_chat [Boolean whether the message was sent to team chat]
  -- @return [String always an empty string, which suppresses the original message]
  function Prefixes:process_prefix(player, prefix_id, prefix, text, team_chat)
    prefix = prefix or ''

    local prefix_data = stored[prefix_id]
    local message = text:utf8sub((text:utf8lower():starts(prefix) and utf8.len(prefix) or 0) + 1)

    if message != '' then
      prefix_data.callback(player, message, team_chat)

      hook.run('PlayerUsedPrefix', player, prefix_id, message, team_chat)
    end

    return ''
  end

  --- Registers a chat prefix, replacing any prefix with the same id. Serverside only.
  -- Messages that start with the prefix go to the callback instead of regular chat.
  -- ```
  -- Prefixes:add('ooc', {
  --   prefix = { '//', '((' },
  --   callback = function(player, message, team_chat)
  --     -- message is the text with the prefix stripped
  --   end
  -- })
  -- ```
  -- @param id [String unique identifier of the prefix]
  -- @param data [Hash prefix (lowercase String or Array<String>), callback (Function that
  --   receives the player, the message without the prefix and team_chat) and optionally
  --   check (Function that receives the full text and returns true if it matches)]
  function Prefixes:add(id, data)
    stored[id] = data
  end
end
