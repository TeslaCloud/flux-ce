PLUGIN:set_global('Prefixes')
PLUGIN:set_name('Prefixes')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds prefix adjusting to avoid troubles with certain commands.')

local stored = {}

function Prefixes:StringIsCommand(str)
  for k, v in ipairs(stored) do
    if istable(v.prefix) then
      for k1, v1 in pairs(v.prefix) do
        if str:utf8lower():starts(v1) then
          return false
        end
      end
    elseif str:utf8lower():starts(v.prefix) then
      return false
    end
  end
end

function Prefixes:PlayerSay(player, text, team_chat)
  if !string.is_command(text) then
    for k, v in ipairs(stored) do
      if istable(v.prefix) then
        for k2, v2 in ipairs(v.prefix) do
          if text:utf8lower():starts(v2) or v.check and v.check(text) then
            local message = text:utf8sub((text:utf8lower():starts(v2) and v2:utf8len() or 0) + 1)

            if message != '' then
              v.callback(player, message, team_chat)
              hook.run('PlayerUsedPrefix', player, v.id, message, team_chat)
            end

            return ''
          end
        end
      elseif text:utf8lower():starts(v.prefix) or v.check and v.check(text) then
        local message = text:utf8sub((text:utf8lower():starts(v.prefix) and v.prefix:utf8len() or 0) + 1)

        if message != '' then
          v.callback(player, message, team_chat)
          hook.run('PlayerUsedPrefix', player, v.id, message, team_chat)
        end

        return ''
      end
    end
  end
end

function Prefixes:add(id, prefix, callback, check)
  table.insert(stored, {
    id = id,
    prefix = prefix,
    callback = callback,
    check = check
  })
end
