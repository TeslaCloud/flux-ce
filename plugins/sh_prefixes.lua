PLUGIN:set_global('Prefixes')
PLUGIN:set_name('Prefixes')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds prefix adjusting to avoid troubles with certain commands.')

local stored = {}

function Prefixes:StringIsCommand(text)
  for k, v in pairs(stored) do
    local prefix_table = istable(v.prefix) and v.prefix or { v.prefix }

    for k1, v1 in pairs(prefix_table) do
      if text:utf8lower():starts(v1) then
        return false
      end
    end
  end
end

if SERVER then
  function Prefixes:PlayerSay(player, text, team_chat)
    if !string.is_command(text) then
      for k, v in pairs(stored) do
        local prefix_table = istable(v.prefix) and v.prefix or { v.prefix }

        for k2, v2 in pairs(prefix_table) do
          if text:utf8lower():starts(v2) or v.check and v.check(text) then
            return self:process_prefix(player, k, v2, text, team_chat)
          end
        end
      end
    end
  end

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

  function Prefixes:add(id, data)
    stored[id] = data
  end
end
